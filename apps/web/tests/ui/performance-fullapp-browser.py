"""Authenticated map/analytics exploration against the disposable audit harness only.

Requires the separate full-app audit harness on loopback port 5183. It creates
synthetic fixtures through the real API and must never target an application DB.
"""
import argparse
from datetime import datetime, timedelta, timezone
import json
import sys
from pathlib import Path
from uuid import uuid4
from playwright.sync_api import sync_playwright

sys.stdout.reconfigure(encoding='utf-8')

parser=argparse.ArgumentParser()
parser.add_argument('--allow-isolated', action='store_true')
parser.add_argument('--label',default='r2')
args=parser.parse_args()
if not args.allow_isolated:
    parser.error('Run only with the disposable audit harness: --allow-isolated')
BASE='http://127.0.0.1:5183'
out=Path(__file__).resolve().parents[2]/'tests/.runtime/performance-audit'
out.mkdir(parents=True,exist_ok=True)

with sync_playwright() as p:
    browser=p.chromium.launch(headless=True,args=['--enable-unsafe-swiftshader'])
    try:
        page=browser.new_page(viewport={'width':1366,'height':900})
        errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto(BASE+'/app/login.html')
        page.wait_for_load_state('networkidle')
        page.locator('input[type=email]').fill('audit-corporate@example.invalid')
        page.locator('input[type=password]').fill('Auditoria Sintetica 2026!')
        page.locator('button[type=submit]').click()
        page.wait_for_url('**/app/home.html')
        token=page.evaluate("localStorage.getItem('astha_token')")
        def request(path,data=None):
            response=page.request.post(BASE+'/api'+path,headers={'Authorization':'Bearer '+token},data=data) if data is not None else page.request.get(BASE+'/api'+path,headers={'Authorization':'Bearer '+token})
            result=response.json()
            if not response.ok:
                raise AssertionError({'path':path,'status':response.status,'error':result.get('error')})
            return result
        code='AUDIT-PERF-'+uuid4().hex[:8]
        asset=request('/eam/assets',{'asset_code':code,'name':'Compressor sintético de auditoria'})
        asset_id=asset['id']
        readings=[0,2,3,4,4,5,6,8]
        for value in readings:
            request(f'/eam/assets/{asset_id}/condition/readings',{'metric_code':'audit_pressure','value':value,'unit':'bar','source':'manual'})
        day=(datetime.now(timezone.utc)-timedelta(days=2)).replace(hour=0,minute=0,second=0,microsecond=0)
        iso=lambda hour:(day+timedelta(hours=hour)).isoformat().replace('+00:00','Z')
        request(f'/eam/assets/{asset_id}/observations',{'request_key':str(uuid4()),'kind':'failure','started_at':iso(9),'ended_at':iso(11),'repair_started_at':iso(9.25),'repair_ended_at':iso(10.25),'source':'Auditoria sintética','notes':'Fixture isolada de reparo ativo de uma hora.','confirmed':True})
        print('FIXTURES',json.dumps({'asset':code,'readings':len(readings),'repairHours':1}),flush=True)
        page.goto(BASE+'/app/sistema.html?tab=mapa')
        page.wait_for_load_state('networkidle')
        # An empty tenant opens the first-warehouse dialog automatically. When
        # maps already exist, exercise the explicit New Map action instead.
        if not page.locator('#warehouseCreateDialog').is_visible():
            page.get_by_role('button',name='Novo Mapa',exact=True).click()
        page.locator('#warehouseCreateName').fill('Mapa sintético '+code)
        with page.expect_response(lambda r:'/api/warehouse/tabs' in r.url and r.request.method=='POST') as created:
            page.locator('#warehouseCreateSubmit').click()
        assert created.value.status==201,created.value.status
        created_data=created.value.json()
        warehouse_id=created_data.get('data',created_data)['id']
        page.wait_for_selector('#cadCanvas2d:visible')
        page.wait_for_timeout(750)
        print('EDITOR',json.dumps(page.evaluate('''()=>({buttons:[...document.querySelectorAll('button')].filter(b=>b.getClientRects().length).map(b=>({id:b.id,text:b.innerText,title:b.title})),canvas:{width:document.getElementById('cadCanvas2d')?.clientWidth,height:document.getElementById('cadCanvas2d')?.clientHeight}})'''),ensure_ascii=False),flush=True)
        page.screenshot(path=str(out/(args.label+'-editor.png')),full_page=True)
        page.get_by_role('button',name='PAREDE',exact=True).click()
        canvas=page.locator('#cadCanvas2d')
        canvas.scroll_into_view_if_needed()
        rect=canvas.bounding_box()
        page.mouse.move(rect['x']+50,rect['y']+85)
        page.mouse.down()
        page.mouse.move(rect['x']+240,rect['y']+85,steps=5)
        page.mouse.up()
        assert page.evaluate('()=>blueprint.floors[currentFloor].walls.length')==1
        page.get_by_role('button',name='Desfazer',exact=True).click()
        assert page.evaluate('()=>blueprint.floors[currentFloor].walls.length')==0
        page.get_by_role('button',name='Refazer',exact=True).click()
        assert page.evaluate('()=>blueprint.floors[currentFloor].walls.length')==1
        page.get_by_role('button',name='Publicar',exact=True).click()
        page.locator('#save-proj-name').fill('Mapa sintético '+code)
        with page.expect_response(lambda r:'/api/warehouse/layout' in r.url and r.request.method=='PUT') as published:
            page.get_by_role('button',name='Confirmar Salvar',exact=True).click()
        assert published.value.status==200,{'publishStatus':published.value.status,'error':published.value.json().get('error')}
        persisted=request('/warehouse/layout?warehouse_id='+str(warehouse_id))
        persisted=persisted.get('data',persisted)
        assert len(persisted['blueprint_data']['floors']['0']['walls'])==1
        page.goto(BASE+'/app/sistema.html?tab=mapa&warehouse='+str(warehouse_id))
        page.wait_for_load_state('networkidle')
        page.locator('#btnMapEditor').click()
        page.wait_for_selector('#cadCanvas2d:visible')
        page.wait_for_function('()=>blueprint.floors[currentFloor].walls.length===1')
        map_state={'createdViaForm':True,'wallDrawn':True,'undoRedoWorks':True,'publishedWalls':1,'reloadPreservesWall':True}
        print('MAP_PERSISTENCE',json.dumps(map_state),flush=True)
        page.goto(BASE+'/app/analytics.html?mode=live&liveArea=measurements&livePage=distribution&asset_code='+code)
        page.wait_for_load_state('networkidle')
        page.wait_for_function("()=>document.querySelector('[data-live-page=distribution] figure')")
        page.wait_for_timeout(500)
        before=page.evaluate('''()=>({figures:document.querySelector('[data-live-page=distribution]').querySelectorAll('figure').length,finite:![...document.querySelector('[data-live-page=distribution]').querySelectorAll('path')].some(p=>/NaN|Infinity/.test(p.getAttribute('d')||'')),text:document.querySelector('[data-live-page=distribution]').innerText})''')
        page.screenshot(path=str(out/(args.label+'-gauss.png')),full_page=True)
        page.get_by_role('button',name='Pausar atualização',exact=True).click()
        page.wait_for_timeout(200)
        paused=page.get_by_role('button',name='Retomar atualização',exact=True).get_attribute('aria-pressed')=='true'
        page.get_by_role('button',name='Retomar atualização',exact=True).click()
        page.wait_for_timeout(500)
        page.get_by_role('link',name='Confiabilidade',exact=True).click()
        page.wait_for_selector('[data-live-page=mttr]:visible')
        mttr=page.locator('[data-live-page=mttr]').inner_text()
        assert '1' in mttr,mttr
        page.screenshot(path=str(out/(args.label+'-mttr.png')),full_page=True)
        page.route('**/api/analytics/sources/eam/operational?**',lambda route:route.fulfill(status=503,content_type='application/json',body='{"error":"Falha de rede sintética"}'))
        page.get_by_role('button',name='Atualizar agora',exact=True).click()
        page.wait_for_function("()=>document.body.innerText.includes('Falha de rede sintética')")
        preserved=page.locator('[data-live-page=mttr] figure').count()>0
        page.unroute('**/api/analytics/sources/eam/operational?**')
        page.get_by_role('button',name='Atualizar agora',exact=True).click()
        page.wait_for_function("()=>!document.body.innerText.includes('Falha de rede sintética')")
        page.set_viewport_size({'width':390,'height':844})
        page.wait_for_timeout(250)
        overflow=page.evaluate('document.documentElement.scrollWidth-innerWidth')
        chart_metrics=page.evaluate('''()=>{const svg=document.querySelector('[data-live-page=mttr] svg'),label=svg.querySelector('text'),figure=svg.closest('figure');return{svgWidth:svg.getBoundingClientRect().width,figureWidth:figure.clientWidth,figureScrollWidth:figure.scrollWidth,effectiveLabelPixels:parseFloat(getComputedStyle(label).fontSize)*svg.getScreenCTM().a};}''')
        page.screenshot(path=str(out/(args.label+'-mttr-phone.png')),full_page=True)
        dataset=request('/analytics/sources/eam/operational?asset_code='+code)
        assert dataset['reliability'][0 if dataset['reliability'][0]['asset_code']==code else next(i for i,r in enumerate(dataset['reliability']) if r['asset_code']==code)]['mttr_hours']==1
        result={'syntheticAsset':code,'map':map_state,'gauss':before,'pauseResumeWorks':paused,'mttrHours':1,'networkFailurePreservesChart':preserved,'phoneHorizontalOverflow':overflow,'phoneChartMetrics':chart_metrics,'errors':errors,'readingCount':len(dataset['readings'])}
        (out/(args.label+'-fullapp.json')).write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf8')
        print('RESULT',json.dumps(result,ensure_ascii=False),flush=True)
        assert not errors,errors
        assert before['finite'] and before['figures']>=2,before
        assert paused and preserved
        assert overflow<=1,overflow
        assert chart_metrics['effectiveLabelPixels']>=12,chart_metrics
        assert chart_metrics['figureScrollWidth']>chart_metrics['figureWidth'],chart_metrics
    finally:
        browser.close()
