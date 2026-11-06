"""Real browser onboarding/recovery checks against the disposable TCC sandbox."""
import json
import uuid
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tests/.runtime/tcc-browser'
BASE='http://127.0.0.1:3001'
PASSWORD='TCC Fluxo Sintetico 2026!'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True)
        try:
            for mode in ['corporate','personal']:
                context=browser.new_context(viewport={'width':1440,'height':960},locale='pt-BR')
                try:
                    page=context.new_page()
                    errors=[]
                    page.on('pageerror',lambda error:errors.append(str(error)))
                    email='tcc-onboarding-'+uuid.uuid4().hex+'@example.invalid'
                    registration=context.request.post(BASE+'/api/auth/register',data={'name':'Pessoa sintética','email':email,'password':PASSWORD})
                    assert registration.status==201, 'REGISTRATION_FAILED'
                    identity=registration.json()
                    page.goto(BASE+'/app/login.html',wait_until='networkidle')
                    page.get_by_label('E-mail',exact=True).fill(email)
                    page.locator('#password').fill(PASSWORD)
                    page.get_by_role('button',name='Entrar',exact=True).click()
                    page.wait_for_url('**/app/onboarding.html',timeout=30000)
                    page.wait_for_load_state('networkidle')
                    page.locator('[name=obWorkspaceType][value='+mode+']').check()
                    page.get_by_role('button',name='Continuar para o perfil',exact=True).click()
                    page.locator('#step2.active').wait_for()
                    page.locator('#obName').fill('Pessoa de teste')
                    page.locator('#obSurname').fill('Persistência')
                    page.locator('#obProfileContinue').click()
                    if mode=='corporate':
                        page.locator('#step3.active').wait_for()
                        page.locator('#step3 button[onclick="handleOrgChoice()"]').click()
                    page.locator('#step4.active').wait_for()
                    page.locator('#obOrgName').fill('Espaço sintético '+mode)
                    if mode=='corporate':
                        page.locator('#obCnpj').fill('12345678000199')
                        page.locator('#obOrgEmail').fill('empresa@example.invalid')
                        page.locator('#obCity').fill('Limeira')
                        page.locator('#obState').select_option('SP')
                    page.locator('#step4 button[onclick="saveOrgData()"]').click()
                    if mode=='corporate':
                        page.locator('#step5.active').wait_for()
                        for name in ['Técnico de manutenção','Gestor de operações']:
                            page.locator('#posName').fill(name)
                            page.locator('#posDept').fill('Manutenção')
                            page.locator('button[onclick="addPosition()"]').click()
                        failed=[False];lost=[False]
                        def fail_second(route):
                            if route.request.method=='POST' and 'Técnico de manutenção' in route.request.post_data and not lost[0]:
                                committed=route.fetch()
                                assert committed.status==201
                                lost[0]=True
                                route.abort('failed')
                            elif route.request.method=='POST' and 'Gestor de operações' in route.request.post_data:
                                failed[0]=True
                                route.fulfill(status=503,content_type='application/json',body=json.dumps({'error':'Indisponibilidade de teste'}))
                            else: route.continue_()
                        page.route('**/api/org/positions',fail_second)
                        page.locator('#step5 button[onclick="savePositions()"]').click()
                        page.get_by_text('Não foi possível salvar todos os cargos:',exact=False).wait_for()
                        assert lost[0] and page.locator('#step5').is_visible()
                        page.locator('#step5 button[onclick="savePositions()"]').click()
                        page.locator('#obAlertMsg').filter(has_text='Indisponibilidade de teste').wait_for()
                        assert failed[0] and page.locator('#step5').is_visible()
                        page.unroute('**/api/org/positions',fail_second)
                        page.locator('#step5 button[onclick="savePositions()"]').click()
                        page.locator('#step6.active').wait_for()
                        page.reload(wait_until='networkidle')
                        assert page.locator('#obCity').input_value()=='Limeira'
                        assert page.locator('#obOrgEmail').input_value()=='empresa@example.invalid'
                        assert page.locator('#posList .ob-pos-card').count()==2
                        # Resume using the real navigation controls; previously committed cargos stay unique.
                        page.locator('[name=obWorkspaceType][value=corporate]').check()
                        page.get_by_role('button',name='Continuar para o perfil',exact=True).click()
                        page.locator('#obProfileContinue').click()
                        page.locator('#step3 button[onclick="handleOrgChoice()"]').click()
                        page.locator('#step4 button[onclick="saveOrgData()"]').click()
                        page.locator('#step5 button[onclick="savePositions()"]').click()
                    page.locator('#step6.active').wait_for()
                    page.screenshot(path=str(OUT/(mode+'-onboarding.png')),full_page=True)
                    page.locator('button[onclick="finishSetup()"]').click()
                    page.wait_for_url('**/app/'+('home.html' if mode=='corporate' else 'personal.html'),timeout=30000)
                    page.wait_for_load_state('networkidle')
                    for width in [1440,390]:
                        page.set_viewport_size({'width':width,'height':960})
                        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth+2')
                        page.screenshot(path=str(OUT/(mode+'-'+str(width)+'.png')),full_page=True)
                    assert not errors, 'PAGE_EXCEPTION'
                    print(json.dumps({'status':'TCC_ONBOARDING_PASSED','mode':mode,'realRegistration':True,'pageErrors':0,'resumeAndRetry':mode=='corporate'}),flush=True)
                finally: context.close()
        finally: browser.close()

if __name__=='__main__': main()
