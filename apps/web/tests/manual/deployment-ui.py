"""Explicit production check using disposable tenants; no user's credentials/data."""
import json
import os
import subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tests' / '.runtime' / 'deployment-2026-11-05-ui'
BASE = 'https://136.111.89.192'
SSH = ['ssh', '-i', str(Path(os.environ['LOCALAPPDATA']) / 'ASTHA-RAVEN/deployment/id_ed25519'),
       '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
       '-o', 'ConnectTimeout=8', 'ciroeduardoarrudacosta@136.111.89.192',
       'sudo', '-n', '/opt/astha/node/bin/node', '.astha-deploy/ui-fixture.cjs']

def fixture(action, mode=None, value=None):
    command = SSH + [action] + ([mode] if mode else [])
    result = subprocess.run(command, input=json.dumps(value) if value else None,
                            capture_output=True, text=True, timeout=40, check=True)
    return json.loads(result.stdout)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        try:
            for mode in ['corporate', 'personal']:
                account = fixture('create', mode)
                context = browser.new_context(viewport={'width': 1440, 'height': 960}, locale='pt-BR')
                try:
                    page = context.new_page()
                    errors = []
                    page.on('pageerror', lambda error: errors.append(str(error)))
                    page.goto(BASE + '/app/login.html', wait_until='networkidle')
                    page.get_by_label('E-mail', exact=True).fill(account['email'])
                    page.locator('#password').fill(account['password'])
                    page.get_by_role('button', name='Entrar', exact=True).click()
                    page.wait_for_url('**/app/' + ('home.html' if mode == 'corporate' else 'personal.html'), timeout=30000)
                    page.wait_for_load_state('networkidle')
                    if mode == 'corporate':
                        page.goto(BASE + '/app/sistema.html?tab=estoque', wait_until='networkidle')
                        if page.locator('#warehouseCreateName').is_visible():
                            page.locator('#warehouseCreateName').fill('Temporary deployment verification')
                            with page.expect_response(lambda r: '/api/warehouse/tabs' in r.url and r.request.method == 'POST') as response:
                                page.get_by_role('button', name='Criar e abrir mapa', exact=True).click()
                            assert response.value.status == 201
                            page.wait_for_selector('#warehouseCreateDialog', state='hidden')
                        page.goto(BASE + '/app/sistema.html?tab=estoque', wait_until='networkidle')
                        page.get_by_role('button', name='+ Novo Material', exact=True).click()
                        page.locator('#matDesc').fill('Temporary UI stock verification')
                        page.locator('#matInitQty').fill('1.25')
                        page.locator('#matPrice').fill('12.34')
                        with page.expect_response(lambda r: r.url.endswith('/api/materials') and r.request.method == 'POST') as created:
                            page.locator('#materialSubmitBtn').click()
                        material = created.value.json()
                        assert created.value.status == 201 and material['created_by'] is not None
                        page.wait_for_timeout(500)
                        for tab, prefix, quantity, label, expected in [('Entrada (+)', 'entry', '1.125', 'Registrar Entrada', 2.375), ('Saída (-)', 'exit', '0.125', 'Registrar Saída', 2.25)]:
                            page.get_by_role('button', name=tab, exact=True).click()
                            page.locator('#' + prefix + 'Code').fill(material['code'])
                            page.locator('#' + prefix + 'Qty').fill(quantity)
                            if prefix == 'entry': page.locator('#entryPrice').fill('8.75')
                            with page.expect_response(lambda r: '/api/movements/' in r.url and r.request.method == 'POST') as movement:
                                page.get_by_role('button', name=label, exact=True).click()
                            assert movement.value.status == 201 and float(movement.value.json()['new_stock']) == expected
                        confirmed = page.evaluate("async code => { const r=await API.get('/materials/'+encodeURIComponent(code)); return Number(r.data?.quantity); }", material['code'])
                        assert confirmed == 2.25
                        page.get_by_role('button', name='Estoque', exact=True).click()
                    for width in [1440, 390]:
                        page.set_viewport_size({'width': width, 'height': 960})
                        page.wait_for_timeout(500)
                        page.screenshot(path=str(OUT / f'{mode}-{width}.png'), full_page=True)
                        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth + 2')
                    assert not errors, 'PAGE_EXCEPTION'
                    print(json.dumps({'status': 'DEPLOYMENT_UI_PASSED', 'mode': mode, 'widths': [1440, 390], 'pageErrors': len(errors), 'realHttps': True}))
                finally:
                    context.close()
                    assert fixture('cleanup', value={'org': account['org']})['status'] == 'UI_FIXTURE_REMOVED'
        finally:
            browser.close()

if __name__ == '__main__':
    main()
