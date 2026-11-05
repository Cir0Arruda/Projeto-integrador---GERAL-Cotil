'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),{JSDOM}=require('jsdom');
const settle=()=>new Promise(resolve=>setImmediate(resolve));
const assets=[{id:11,asset_code:'EQ-11',name:'Bomba',status:'active',criticality:'high'}];
const orders=[{id:21,asset_id:11,work_order_number:'OS-21',title:'Inspecionar bomba',status:'open'}];
async function setup(query='?tab=eam'){
 const dom=new JSDOM(fs.readFileSync('app/sistema.html','utf8'),{url:'http://localhost/app/sistema.html'+query,runScripts:'outside-only'}),w=dom.window,calls=[];
 w.Auth={requireAuth:()=>false,getUser:()=>null,getUserRole:()=>'admin',canManageUsers:()=>true};w.showToast=()=>{};w.HTMLElement.prototype.scrollIntoView=()=>{};
 w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};w.HTMLDialogElement.prototype.close=function(){this.open=false;this.dispatchEvent(new w.Event('close'));};
 w.API={get:async url=>{calls.push(url);return {success:true,data:url==='/eam/assets'?assets:url==='/eam/work-orders'?orders:url.endsWith('/observations')?{records:[],has_more:false}:url.endsWith('/condition')?{rules:[],readings:[],alerts:[]}:url.includes('/reliability/assets/')?{exposure:{},warnings:[]}:url.startsWith('/eam/reliability/summary')?{assets:[]}:url==='/eam/plan-templates'?[{id:1,name:'Inspeção semanal',definition:{interval_days:7,tasks:['Inspecionar'],priority:'high'}}]:[]};},post:async(url,body)=>{calls.push({url,body});return {success:true,data:{id:2}};}};
 for(const file of ['security.js','sistema-core.js','maintenance-calendar.js','eam-preventives.js','eam-ux.js','eam-observations.js','eam-planning-tools.js','eam-procurement-navigation.js'])w.eval(fs.readFileSync('app/js/'+file,'utf8'));
 await settle();await settle();
 const ids=[...w.document.querySelectorAll('#panel-eam [id], dialog [id]')].map(node=>node.id);
 w.eval(fs.readFileSync('app/js/eam-navigation.js','utf8'));await settle();await settle();
 return {dom,w,calls,ids};
}
async function close(w){await settle();await settle();w.close();}

test('all EAM modules have separate pages and keep original controls and in-progress forms',async()=>{
 const {w,ids}=await setup();try{
  for(const id of ids)assert.equal(w.document.querySelectorAll('[id="'+id+'"]').length,1,id);
  assert.equal(w.document.querySelectorAll('.eam-module-pages').length,4);
  w.EamNavigation.go('assets','locations','edit');w.document.querySelector('#eamLocationName').value='Sala de bombas';
  assert.equal(w.document.querySelector('#eamLocationForm').closest('.eam-module-page').hidden,false);assert.equal(w.document.querySelector('#eamLocationsTree').closest('.eam-module-page').hidden,true);
  w.EamNavigation.go('plans','planning','calendar');assert.equal(w.document.querySelector('#eamPlanCalendar').closest('.eam-module-page').hidden,false);assert.equal(w.document.querySelector('#eamPlansBody').closest('.eam-module-page').hidden,true);assert.equal(w.document.querySelector('#eamPlanMetrics').closest('.eam-module-page').hidden,true);
  w.EamNavigation.go('assets','locations','edit');assert.equal(w.document.querySelector('#eamLocationName').value,'Sala de bombas');
  for(const section of ['assets','orders','plans','reliability'])assert.equal(w.document.querySelectorAll('#eam-'+section+' .eam-module-page:not([hidden])').length,1);
  assert.equal(w.document.querySelector('#eam-assets > details'),null);assert.equal(w.document.querySelector('#eam-reliability > details'),null);
 }finally{await close(w);}
});

test('direct EAM page addresses, browser history and procurement routing use one history owner',async()=>{
 const {w}=await setup('?tab=eam&warehouse=7&eamSection=plans&eamArea=configuration&eamPage=counters');try{
  assert.equal(w.document.querySelector('#eamCounterAsset').closest('.eam-module-page').hidden,false);
  const saved=w.location.href,count=w.history.length;w.EamNavigation.go('reliability','condition','limits');assert.equal(w.history.length,count+1);
  w.EamProcurementNavigation.go('planning','forecasts');assert.equal(w.history.length,count+2);assert.equal(new URL(w.location).searchParams.get('eamPage'),null);assert.equal(new URL(w.location).searchParams.get('procurementPage'),'forecasts');
  w.history.replaceState(null,'',saved);w.dispatchEvent(new w.PopStateEvent('popstate'));await settle();assert.equal(w.document.querySelector('#eamCounterAsset').closest('.eam-module-page').hidden,false);assert.equal(new URL(w.location).searchParams.get('warehouse'),'7');
  w.history.replaceState(null,'','?tab=eam&eamSection=plans&eamArea=__proto__&eamPage=constructor');w.dispatchEvent(new w.PopStateEvent('popstate'));assert.equal(new URL(w.location).searchParams.get('eamPage'),'calendar');
 }finally{await close(w);}
});

test('new order page loads assets and saves through the original flow without a modal',async()=>{
 const {w,calls}=await setup();try{
  await w.toggleEamOrderForm(true);assert.equal(w.document.querySelector('#eamOrderCreateForm').closest('.eam-module-page').hidden,false);assert.equal(w.document.querySelector('dialog[open]'),null);
  w.document.querySelector('#eamOrderAsset').value='11';w.document.querySelector('#eamOrderTitle').value='Verificar bomba';w.renderEam=async()=>{};
  await w.createEamWorkOrder({preventDefault(){},target:w.document.querySelector('#eamOrderCreateForm')});const post=calls.find(value=>value.url==='/eam/work-orders');assert.equal(post.body.asset_id,11);assert.equal(post.body.title,'Verificar bomba');assert.equal(new URL(w.location).searchParams.get('eamPage'),'list');
 }finally{await close(w);}
});

test('preventive models apply to the create page and daily agenda retains the selected date',async()=>{
 const {w}=await setup();try{
  w.eamPlanState.assets=assets;w.document.querySelector('#eamPlanAsset').add(new w.Option('Bomba','11'));
  w.EamNavigation.go('plans','configuration','templates');await settle();await settle();
  const apply=[...w.document.querySelectorAll('#eam-page-plans-configuration-templates button')].find(node=>node.textContent==='Aplicar');assert.ok(apply);apply.click();
  assert.equal(new URL(w.location).searchParams.get('eamPage'),'create');assert.equal(w.document.querySelector('#eamPlanForm').closest('.eam-module-page').hidden,false);assert.equal(w.document.querySelector('#eamPlanInterval').value,'7');assert.equal(w.eamPlanExtras().priority,'high');
  w.eamPlanState.day='2026-11-12';w.EamNavigation.go('plans','planning','agenda');assert.equal(w.document.querySelector('#eamAgendaDate').value,'2026-11-12');
 }finally{await close(w);}
});

test('reliability tools and observations use their own pages with the chosen equipment',async()=>{
 const {w,calls}=await setup('?tab=eam&eamSection=reliability&eamArea=records&eamPage=observations');try{
  assert.equal(w.document.querySelector('#eam-page-reliability-records-observations button[type=submit]').disabled,false);
  w.EamNavigation.go('reliability','condition','limits');await settle();await settle();assert.equal(w.document.querySelector('#eamConditionAsset').value,'11');assert.equal(w.document.querySelector('#eamConditionMetric').closest('.eam-module-page').hidden,false);
  w.EamNavigation.go('reliability','records','observations');await settle();assert.ok(calls.includes('/eam/assets/11/observations'));assert.equal(w.document.querySelector('#eamObservationsDialog form'),null);assert.equal(w.document.querySelector('dialog[open]'),null);
  w.EamNavigation.go('reliability','indicators','projection');await settle();assert.match(w.document.querySelector('#eam-page-reliability-indicators-projection').textContent,/taxa constante/);
  w.EamNavigation.go('reliability','condition','devices');await settle();await settle();assert.match(w.document.querySelector('#eam-page-reliability-condition-devices').textContent,/Cadastrar dispositivo/);
 }finally{await close(w);}
});

test('asset and order record subpages restore from URLs and return to their parent list',async()=>{
 const {w}=await setup('?tab=eam&eamSection=orders&eamArea=orders&eamPage=list&eamOrder=21&eamView=labor');try{
  assert.equal(w.document.querySelector('#eamOrderWorkspace').hidden,false);assert.match(w.document.querySelector('#eamOrderWorkspace .eam-workspace-body').textContent,/horas trabalhadas/);assert.equal(w.document.querySelector('#eamLaborOrder').value,'21');
  w.closeEamOrderWorkspace();assert.equal(new URL(w.location).searchParams.get('eamOrder'),null);
  w.openEamAssetWorkspace(assets[0]);assert.equal(new URL(w.location).searchParams.get('eamAsset'),'11');
  const history=[...w.document.querySelectorAll('#eamAssetWorkspace .eam-workspace-tab')].find(node=>node.textContent==='Histórico');assert.equal(history.tagName,'A');history.click();assert.equal(new URL(w.location).searchParams.get('eamView'),'history');
  const route=w.location.href;w.closeEamAssetWorkspace();w.history.replaceState(null,'',route);w.dispatchEvent(new w.PopStateEvent('popstate'));await settle();await settle();assert.equal(w.document.querySelector('#eamAssetWorkspace').hidden,false);assert.equal(w.document.querySelector('#eamAssetWorkspace .eam-workspace-tab[aria-current=page]').textContent,'Histórico');
 }finally{await close(w);}
});

test('assembly configuration becomes individual subpages without breaking 3D editor shortcuts',async()=>{
 const {w}=await setup();try{
  const actions=w.document.createElement('aside');actions.innerHTML='<h4>Configuração do ativo</h4><details><summary>Montar partes 3D</summary><input aria-label="Posição X"></details><details><summary>Adicionar módulo</summary><input aria-label="Nome do módulo"></details>';w.document.body.append(actions);
  w.EamNavigation.organizeAssembly(actions,assets[0]);const moduleLink=[...actions.querySelectorAll('nav a')].find(node=>node.textContent==='Adicionar módulo');moduleLink.click();const groups=actions.querySelectorAll('details');
  assert.equal(groups[0].hidden,true);assert.equal(groups[1].hidden,false);assert.equal(new URL(w.location).searchParams.get('eamTool'),'module');assert.equal(new URL(w.location).searchParams.get('eamView'),'structure');
  const name=actions.querySelector('[aria-label="Nome do módulo"]');name.value='Motor principal';groups[0].open=true;await settle();await settle();assert.equal(groups[0].hidden,false);assert.equal(groups[1].hidden,true);moduleLink.click();assert.equal(name.value,'Motor principal');
 }finally{await close(w);}
});
