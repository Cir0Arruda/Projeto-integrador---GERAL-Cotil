"""Browser reconnaissance against the explicitly disposable full-app audit server."""
import json
import sys
import os
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:5183"
OUT = Path(__file__).resolve().parents[1] / ".runtime" / "audit-2026-11-05-browser" / os.environ.get("ASTHA_AUDIT_ROUND", "r2")
OUT.mkdir(parents=True, exist_ok=True)
sys.stdout.reconfigure(encoding="utf-8")

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1440, "height": 960}, locale="pt-BR")
        page = context.new_page()
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(BASE + "/app/login.html", wait_until="networkidle")
        page.screenshot(path=str(OUT / "login-1440.png"), full_page=True)
        page.get_by_label("E-mail", exact=True).fill("audit-corporate@example.invalid")
        page.locator("#password").fill("Auditoria Sintetica 2026!")
        page.get_by_role("button", name="Entrar", exact=True).click()
        page.wait_for_url("**/app/home.html", timeout=30000)
        page.wait_for_load_state("networkidle")
        page.screenshot(path=str(OUT / "home-1440.png"), full_page=True)
        print(json.dumps({"url": page.url, "errors": errors,
            "buttons": page.get_by_role("button").all_text_contents(),
            "links": page.get_by_role("link").all_text_contents()}, ensure_ascii=False))
        page.goto(BASE + "/app/sistema.html?tab=estoque", wait_until="networkidle")
        page.screenshot(path=str(OUT / "stock-1440.png"), full_page=True)
        print(json.dumps({"stockUrl": page.url, "errors": errors,
            "buttons": page.get_by_role("button").all_text_contents(),
            "text": page.locator("main").inner_text()[:5000]}, ensure_ascii=False))
        if page.locator("#warehouseCreateName").is_visible():
            page.locator("#warehouseCreateName").fill("Armazém sintético de auditoria")
            with page.expect_response(lambda r: "/api/warehouse/tabs" in r.url and r.request.method == "POST") as created:
                page.get_by_role("button", name="Criar e abrir mapa", exact=True).click()
            assert created.value.status == 201, created.value.text()
            page.wait_for_selector("#warehouseCreateDialog", state="hidden")
        page.goto(BASE + "/app/sistema.html?tab=estoque", wait_until="networkidle")
        page.get_by_role("button", name="+ Novo Material", exact=True).click()
        page.locator("#matDesc").fill("Material sintético de auditoria")
        page.locator("#matInitQty").fill("1.25")
        page.locator("#matPrice").fill("12.34")
        page.screenshot(path=str(OUT / "material-form-1440.png"), full_page=True)
        with page.expect_response(lambda r: r.url.endswith("/api/materials") and r.request.method == "POST") as material:
            page.locator("#materialSubmitBtn").click()
        created_material = material.value.json()
        assert material.value.status == 201, created_material
        assert float(created_material['quantity']) == 1.25
        assert float(created_material['unit_price']) == 12.34
        assert created_material['created_by'] is not None
        code = created_material['code']
        page.wait_for_timeout(1000)
        page.screenshot(path=str(OUT / "material-after-save-1440.png"), full_page=True)
        print(json.dumps({"errors": errors, "inputs": page.locator("input,select").evaluate_all("els=>els.filter(e=>e.offsetWidth).map(e=>({id:e.id,type:e.type,placeholder:e.placeholder}))")}, ensure_ascii=False))
        page.get_by_role('button', name='Entrada (+)', exact=True).click()
        page.locator('#entryCode').fill(code)
        page.locator('#entryQty').fill('1.125')
        page.locator('#entryPrice').fill('8.75')
        with page.expect_response(lambda r: '/api/movements/entry' in r.url and r.request.method == 'POST') as entry:
            page.get_by_role('button', name='Registrar Entrada', exact=True).click()
        assert entry.value.status == 201, entry.value.text()
        assert float(entry.value.json()['new_stock']) == 2.375
        page.get_by_role('button', name='Saída (-)', exact=True).click()
        page.locator('#exitCode').fill(code)
        page.locator('#exitQty').fill('0.125')
        with page.expect_response(lambda r: '/api/movements/exit' in r.url and r.request.method == 'POST') as withdrawal:
            page.get_by_role('button', name='Registrar Saída', exact=True).click()
        assert withdrawal.value.status == 201, withdrawal.value.text()
        assert float(withdrawal.value.json()['new_stock']) == 2.25
        confirmed = page.evaluate('''async code => {
          const r=await API.get('/materials/'+encodeURIComponent(code));
          return {success:r.success,quantity:Number(r.data?.quantity),author:r.data?.created_by};
        }''', code)
        assert confirmed['success'] and confirmed['quantity'] == 2.25 and confirmed['author'], confirmed
        page.get_by_role('button', name='Estoque', exact=True).click()
        page.wait_for_timeout(500)
        assert '2,25' in page.locator('main').inner_text()
        page.screenshot(path=str(OUT / 'stock-after-movements-1440.png'), full_page=True)
        assert not errors, errors
        print(json.dumps({'passed':True,'flow':'UI create warehouse/material + entry + withdrawal + persisted read', 'stock':confirmed['quantity'],'authorship':bool(confirmed['author']),'pageErrors':errors},ensure_ascii=False))
        context.close()
        browser.close()

if __name__ == "__main__":
    main()
