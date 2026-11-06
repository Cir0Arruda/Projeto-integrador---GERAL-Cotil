"""Browser QA against production HTML/CSS/JS with synthetic API responses only."""
import json
import shutil
import base64
import os
import time
from pathlib import Path
from urllib.parse import urlsplit
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
LABEL = os.getenv('UI_AUDIT_LABEL', '')
OUT = ROOT / 'tests' / '.runtime' / ('ui-browser-audit'+('-'+LABEL if LABEL else ''))
OUT.mkdir(parents=True, exist_ok=True)
BEFORE = OUT / 'before'
BEFORE.mkdir(exist_ok=True)
for saved in OUT.glob('390-settings*.png'):
    if not (BEFORE / saved.name).exists():
        shutil.copy2(saved, BEFORE / saved.name)
USER = {'id': 1, 'name': 'Pessoa', 'surname': 'Teste', 'email': 'qa@example.invalid',
        'role': 'admin', 'org_id': 'qa-fixture', 'org_name': 'Organização de conferência visual',
        'org_plan': 'enterprise', 'workspace_type': 'company', 'setup_done': False}
MATERIALS = [{'id': 1, 'code': 'QA-01', 'description': 'Material de escritório',
              'quantity': 1.25, 'min_qty': 2, 'unit_price': 12.34, 'warehouse_id': 1}]
UPLOADS = []

def fixture(route):
    endpoint = urlsplit(route.request.url).path.removeprefix('/api')
    data = []
    if endpoint == '/auth/me': data = USER
    elif endpoint == '/auth/profile' and route.request.method == 'PUT':
        payload = route.request.post_data_json
        if 'avatar_url' in payload:
            UPLOADS.append(payload)
        data = {'message': 'Perfil de teste atualizado'}
    elif endpoint == '/auth/oauth-config': data = {'google': {'enabled': False}}
    elif endpoint == '/org/me': data = {'id': 'qa-fixture', 'name': USER['org_name'], 'workspace_type': 'company', 'setup_done': False, 'plan': 'enterprise'}
    elif endpoint == '/org/access/me': data = {'restricted': False, 'permissions': {'wms': True, 'eam': True, 'components': True}}
    elif endpoint == '/org/groups': data = {'groups': [], 'members': []}
    elif endpoint == '/org/profile-design': data = {'color': '#111111', 'logo_url': None}
    elif endpoint == '/org/users': data = [USER]
    elif endpoint == '/warehouse/tabs': data = [{'id': 1, 'name': 'Espaço de teste', 'warehouse_id': 1}]
    elif endpoint == '/materials': data = MATERIALS
    elif endpoint == '/account': data = {'email': USER['email'], 'provider': 'local', 'canChangeCredentials': True}
    elif endpoint == '/account/sessions': data = [{'id': 'synthetic', 'is_current': True, 'device': 'Navegador de teste', 'created_at': '2026-11-05T12:00:00Z'}]
    elif endpoint == '/personal/state': data = {'spaces': [], 'belongings': [], 'tasks': []}
    route.fulfill(status=200, content_type='application/json; charset=utf-8', body=json.dumps(data))

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    results = []
    for width, height in [(1440, 1000), (768, 1024), (390, 844)]:
        if os.getenv('UI_AUDIT_WIDTH') and width != int(os.environ['UI_AUDIT_WIDTH']):
            continue
        context = browser.new_context(viewport={'width': width, 'height': height}, device_scale_factor=1)
        context.add_init_script('localStorage.setItem("astha_token", "synthetic-ui-token"); localStorage.setItem("astha_user", '+json.dumps(json.dumps(USER))+');')
        context.route('**/api/**', fixture)
        context.route('https://**', lambda route: route.abort())
        for path in ['login.html', 'register.html', 'recover.html', 'onboarding.html', 'home.html',
                     'settings.html?tab=workspace', 'settings.html?tab=members', 'settings.html?tab=profile',
                     'account.html', 'sistema.html?tab=estoque']:
            if os.getenv('UI_AUDIT_PAGE') and path != os.environ['UI_AUDIT_PAGE']:
                continue
            page = context.new_page()
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.goto('http://127.0.0.1:5177/app/'+path)
            page.wait_for_load_state('networkidle')
            page.wait_for_timeout(200)
            measurements = page.evaluate('''() => ({
              width: innerWidth, scrollWidth: document.documentElement.scrollWidth,
              main: (()=>{const el=document.querySelector('.app-window > .main-content');if(!el)return null;const r=el.getBoundingClientRect();return {x:r.x,width:r.width,height:r.height}})(),
              outside: [...document.querySelectorAll('main,header,nav,section,button,input,select')]
                .filter(el=>{let r=el.getBoundingClientRect();return r.width&&r.height&&(r.left < -2 || r.right > innerWidth+2)&&getComputedStyle(el).position!=='fixed'})
                .slice(0,15).map(el=>({tag:el.tagName,id:el.id,cls:el.className,text:el.innerText?.slice(0,70),rect:{x:el.getBoundingClientRect().x,width:el.getBoundingClientRect().width}})),
              headings:[...document.querySelectorAll('h1,h2')].filter(el=>el.getClientRects().length).map(el=>el.innerText)
            })''')
            slug = path.replace('?', '-').replace('=', '-')
            page.screenshot(path=str(OUT / f'{width}-{slug}.png'), full_page=True)
            # Exercise actual controls after inspecting the rendered page, without any real API.
            if path.startswith('settings.html?tab=workspace'):
                page.get_by_role('button', name='Editar dados', exact=True).click()
                dialog = page.locator('dialog[open]')
                dialog.wait_for()
                box = dialog.bounding_box()
                assert box['x'] >= -1 and box['x']+box['width'] <= width+1, (path, box)
                page.screenshot(path=str(OUT / f'{width}-company-editor.png'), full_page=True)
                attempts = []
                def company_failure(route):
                    if route.request.method != 'PUT':
                        route.fallback()
                        return
                    attempts.append(route.request.post_data_json)
                    time.sleep(0.15)
                    route.fulfill(status=503,content_type='application/json',body=json.dumps({'error':'Falha sintética ao salvar'}))
                page.route('**/api/org/me',company_failure)
                page.evaluate("document.getElementById('workspaceForm').requestSubmit();document.getElementById('workspaceForm').requestSubmit()")
                page.get_by_text('Falha sintética ao salvar',exact=True).wait_for()
                page.wait_for_load_state('networkidle')
                assert len(attempts) == 1, f'Duplicate company submissions: {len(attempts)}'
                assert page.locator('dialog[open]').count() == 1
                assert page.locator('#workspaceForm [name=name]').input_value() == USER['org_name']
                assert page.locator('#saveWorkspaceButton').is_enabled()
                page.keyboard.press('Escape')
                assert page.locator('dialog[open]').count() == 0
            elif path == 'account.html':
                page.locator('summary').filter(has_text='Alterar senha').click()
                page.locator('#accountPasswordForm [data-show-passwords]').click()
                assert page.locator('#accountPasswordForm input[type="password"]').count() == 0
                page.locator('#accountPasswordForm [data-show-passwords]').click()
                assert page.locator('#accountPasswordForm input[type="password"]').count() > 0
                page.locator('#openAccountDeletion').click()
                page.get_by_role('dialog', name='Excluir minha conta', exact=True).wait_for()
                page.screenshot(path=str(OUT / f'{width}-account-delete-dialog.png'), full_page=True)
                page.keyboard.press('Escape')
                assert page.locator('dialog[open]').count() == 0
            elif path == 'onboarding.html':
                page.locator('input[name="obWorkspaceType"][value="personal"]').check()
                page.get_by_role('button', name='Continuar para o perfil').click()
                page.locator('#step2').wait_for(state='visible')
                page.wait_for_timeout(450)
                page.screenshot(path=str(OUT / f'{width}-onboarding-profile.png'), full_page=True)
                page.locator('#obProfileContinue').click()
                page.locator('#step4').wait_for(state='visible')
                assert page.locator('#step3').is_hidden()
            elif path == 'settings.html?tab=profile':
                encoded = page.evaluate('''() => {
                  const canvas=document.createElement('canvas');canvas.width=720;canvas.height=720;
                  const ctx=canvas.getContext('2d'),pixels=ctx.createImageData(720,720);
                  for(let i=0;i<pixels.data.length;i+=65536)crypto.getRandomValues(pixels.data.subarray(i,i+65536));
                  ctx.putImageData(pixels,0,0);return canvas.toDataURL('image/png').split(',')[1];
                }''')
                photo = base64.b64decode(encoded)
                assert 1_500_000 < len(photo) <= 2*1024*1024
                previous = len(UPLOADS)
                page.locator('#avatarUpload').set_input_files({'name':'synthetic-profile.png','mimeType':'image/png','buffer':photo})
                try:
                    page.get_by_text('Foto de perfil atualizada!',exact=True).wait_for(timeout=5000)
                except Exception:
                    print(json.dumps({'toast':page.locator('#toast').inner_text(),'uploadCount':len(UPLOADS),'pageErrors':errors},ensure_ascii=False),flush=True)
                    raise
                assert len(UPLOADS) == previous+1
                assert list(UPLOADS[-1]) == ['avatar_url']
                assert UPLOADS[-1]['avatar_url'].startswith('data:image/webp;base64,')
                assert len(UPLOADS[-1]['avatar_url']) <= 100000
                page.locator('#avatarUpload').set_input_files({'name':'invalid.png','mimeType':'image/png','buffer':b'not an image'})
                page.wait_for_timeout(100)
                assert len(UPLOADS) == previous+1
            results.append({'page': path, 'viewport': [width,height], 'errors': errors, **measurements})
            page.close()
        context.close()
    browser.close()
    (OUT / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    failures = [r for r in results if r['errors'] or r['scrollWidth'] > r['width']+2 or
                (r['main'] and (r['main']['x'] >= r['width']-30 or r['main']['width'] < 240))]
    print(json.dumps(failures, ensure_ascii=False, indent=2))
    assert not failures, 'Browser errors, page overflow or inaccessible primary content'
