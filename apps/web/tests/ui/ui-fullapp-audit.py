"""UI audit for the disposable full-app harness. Refuses non-loopback hosts."""
import json
import base64
import os
from pathlib import Path
from urllib.parse import urlsplit
from playwright.sync_api import sync_playwright

BASE = 'http://127.0.0.1:5183'
assert urlsplit(BASE).hostname in ['127.0.0.1', 'localhost']
LABEL = os.getenv('UI_AUDIT_LABEL', '')
OUT = Path(__file__).resolve().parents[1] / '.runtime' / ('ui-fullapp-audit'+('-'+LABEL if LABEL else ''))
OUT.mkdir(parents=True, exist_ok=True)
results = []
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    for kind in ['corporate', 'personal']:
        context = browser.new_context(viewport={'width': 1440, 'height': 1000})
        page = context.new_page()
        page.goto(BASE+'/app/login.html')
        page.wait_for_load_state('networkidle')
        page.locator('#email').fill(f'audit-{kind}@example.invalid')
        page.locator('#password').fill('Auditoria Sintetica 2026!')
        page.get_by_role('button', name='Entrar', exact=True).click()
        page.wait_for_url(lambda url: '/login.html' not in url)
        page.wait_for_load_state('networkidle')
        paths = ['home.html', 'settings.html?tab=workspace', 'settings.html?tab=members',
                 'settings.html?tab=profile', 'settings.html?tab=security', 'account.html'] if kind == 'corporate' else ['personal.html', 'personal.html?view=profile', 'account.html']
        for width, height in [(1440,1000), (768,1024), (390,844)]:
            page.set_viewport_size({'width': width, 'height': height})
            for path in paths:
                errors, failures = [], []
                def on_error(error): errors.append(str(error))
                def on_response(response):
                    if response.status >= 400 and '/api/' in response.url:
                        failures.append({'status': response.status, 'endpoint': urlsplit(response.url).path})
                page.on('pageerror', on_error)
                page.on('response', on_response)
                page.goto(BASE+'/app/'+path)
                page.wait_for_load_state('networkidle')
                page.wait_for_timeout(150)
                metrics = page.evaluate('''() => ({width:innerWidth,scrollWidth:document.documentElement.scrollWidth,
                  heading:document.querySelector('h1')?.innerText,bodyText:document.body.innerText.slice(0,300),
                  main:(()=>{let el=document.querySelector('.app-window>.main-content');if(!el)return null;let r=el.getBoundingClientRect();return{x:r.x,width:r.width,height:r.height}})()})''')
                slug = kind+'-'+str(width)+'-'+path.replace('?','-').replace('=','-')
                page.screenshot(path=str(OUT/(slug+'.png')), full_page=True)
                if kind == 'corporate' and path == 'settings.html?tab=workspace':
                    page.get_by_role('button',name='Editar dados',exact=True).click()
                    page.get_by_role('dialog',name='Editar empresa e identidade',exact=True).wait_for()
                    page.screenshot(path=str(OUT/(slug+'-dialog.png')), full_page=True)
                    page.keyboard.press('Escape')
                if path == 'account.html':
                    page.locator('#openAccountDeletion').click()
                    page.get_by_role('dialog',name='Excluir minha conta',exact=True).wait_for()
                    page.keyboard.press('Escape')
                if kind == 'corporate' and width == 1440 and path == 'settings.html?tab=profile':
                    encoded = page.evaluate('''() => {
                      const c=document.createElement('canvas');c.width=720;c.height=720;
                      const ctx=c.getContext('2d'),pixels=ctx.createImageData(720,720);
                      for(let i=0;i<pixels.data.length;i+=65536)crypto.getRandomValues(pixels.data.subarray(i,i+65536));
                      ctx.putImageData(pixels,0,0);return c.toDataURL('image/png').split(',')[1];
                    }''')
                    photo = base64.b64decode(encoded)
                    assert 1_500_000 < len(photo) <= 2*1024*1024
                    page.locator('#avatarUpload').set_input_files({'name':'synthetic-profile.png','mimeType':'image/png','buffer':photo})
                    page.get_by_text('Foto de perfil atualizada!',exact=True).wait_for()
                    confirmed = page.evaluate('''async() => {
                      const r=await fetch('/api/auth/me',{headers:{Authorization:'Bearer '+localStorage.getItem('astha_token')}}),u=await r.json();
                      return {status:r.status,length:u.avatar_url?.length,webp:u.avatar_url?.startsWith('data:image/webp;base64,')};
                    }''')
                    assert confirmed['status'] == 200 and confirmed['webp'] and confirmed['length'] <= 100000, confirmed
                    metrics['avatarPersistence'] = confirmed
                results.append({'account':kind,'page':path,'viewport':[width,height], 'errors':errors,'apiFailures':failures,**metrics})
                page.remove_listener('pageerror',on_error)
                page.remove_listener('response',on_response)
        context.close()
    browser.close()
(OUT/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
issues = [r for r in results if r['errors'] or r['apiFailures'] or r['scrollWidth']>r['width']+2 or (r['main'] and (r['main']['x']>=r['width']-30 or r['main']['width']<240))]
print(json.dumps(issues,ensure_ascii=False,indent=2))
assert not issues, 'Full app audit found runtime/API/geometry failures'
