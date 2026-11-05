'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('jsdom');
const html=fs.readFileSync('app/sistema.html','utf8'),settle=()=>new Promise(resolve=>setImmediate(resolve));
async function setup(query='?tab=eam'){
 const dom=new JSDOM(html,{url:'http://localhost/app/sistema.html'+query,runScripts:'outside-only'}),w=dom.window,calls=[];
 w.Auth={requireAuth:()=>false,getUser:()=>null,getUserRole:()=>'admin',canManageUsers:()=>true};w.showToast=()=>{};w.HTMLElement.prototype.scrollIntoView=()=>{};
 w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};w.HTMLDialogElement.prototype.close=function(){this.open=false;};
 w.API={get:async()=>({success:true,data:[]}),post:async(url,body)=>{calls.push({url,body});return {success:true,data:{po_number:'QA-ORDER'}};}};
 for(const script of ['security.js','sistema-core.js','eam-ux.js','eam-procurement-navigation.js'])w.eval(fs.readFileSync('app/js/'+script,'utf8'));
 await settle();await settle();return {dom,w,calls};
}
test('procurement sections become separate URL-addressable pages and retain every existing form/control',async()=>{
 const original=new JSDOM(html),ids=[...original.window.document.querySelectorAll('#eam-procurement [id]')].map(n=>n.id);original.window.close();
 const {dom,w}=await setup();try{
  w.switchEamSection('procurement',w.document.querySelector('[onclick*="procurement"]'));
  const root=w.document.querySelector('#eam-procurement');assert.equal(root.querySelectorAll(':scope > details').length,0);assert.equal(root.querySelectorAll('.eam-procurement-nav a').length,4);
  for(const id of ids)assert.equal(w.document.querySelectorAll('[id="'+id+'"]').length,1,id);
  const forecast=w.document.querySelector('#eamForecastQuantity');forecast.value='12';w.EamProcurementNavigation.go('planning','forecasts');
  assert.equal(forecast.closest('.eam-procurement-page').hidden,false);assert.equal(root.querySelectorAll('.eam-procurement-page:not([hidden])').length,1);assert.equal(new URL(w.location).searchParams.get('procurementPage'),'forecasts');
  w.EamProcurementNavigation.go('suppliers','rfqs');assert.equal(forecast.closest('.eam-procurement-page').hidden,true);assert.equal(w.document.querySelector('#eamRfqTitle').closest('.eam-procurement-page').hidden,false);
  w.EamProcurementNavigation.go('planning','forecasts');assert.equal(forecast.value,'12');assert.ok(w.document.querySelector('.eam-procurement-subnav [aria-current=page]').href.includes('procurementPage=forecasts'));
 }finally{await settle();await settle();w.close();}
});
test('deep links, reload state and back/forward restore the correct parent and subpage',async()=>{
 const {dom,w}=await setup('?tab=eam&warehouse=7&eamSection=procurement&procurementArea=planning&procurementPage=units');try{
  assert.equal(w.document.querySelector('#eamUnitMaterial').closest('.eam-procurement-page').hidden,false);assert.ok(w.document.querySelector('#panel-eam').classList.contains('active'));assert.ok(w.document.querySelector('#eam-procurement').classList.contains('active'));
  const saved=w.location.href;w.EamProcurementNavigation.go('purchases','receipts');assert.equal(w.document.querySelector('#eamReceiptOrder').closest('.eam-procurement-page').hidden,false);
  w.history.replaceState(null,'',saved);w.dispatchEvent(new w.PopStateEvent('popstate'));assert.equal(w.document.querySelector('#eamUnitMaterial').closest('.eam-procurement-page').hidden,false);assert.equal(w.document.querySelector('#eamReceiptOrder').closest('.eam-procurement-page').hidden,true);assert.equal(new URL(w.location).searchParams.get('warehouse'),'7');
  w.history.replaceState(null,'','?tab=eam&eamSection=procurement&procurementArea=__proto__&procurementPage=bad');w.dispatchEvent(new w.PopStateEvent('popstate'));assert.equal(new URL(w.location).searchParams.get('procurementArea'),'requisitions');
 }finally{await settle();await settle();w.close();}
});
test('approved requisition opens the purchase subpage and saving returns to the order list',async()=>{
 const {dom,w,calls}=await setup();try{
  const requisition=w.document.querySelector('#eamPurchaseReq'),supplier=w.document.querySelector('#eamPurchaseSupplier');requisition.add(new w.Option('QA requisition','22'));supplier.add(new w.Option('QA supplier','33'));
  w.prepareEamPurchaseOrder(22);assert.equal(requisition.value,'22');assert.equal(requisition.closest('.eam-procurement-page').hidden,false);assert.equal(new URL(w.location).searchParams.get('procurementPage'),'create');
  supplier.value='33';w.document.querySelector('#eamPurchasePrice').value='12.50';w.renderEam=async()=>{};
  await w.createEamPurchaseOrder({preventDefault(){},target:w.document.querySelector('#eamPurchaseOrderCreateForm')});assert.equal(calls[0].url,'/eam/purchase-requisitions/22/purchase-orders');assert.equal(calls[0].body.supplier_id,33);assert.equal(calls[0].body.unit_price,12.5);assert.equal(new URL(w.location).searchParams.get('procurementPage'),'orders');assert.equal(w.document.querySelector('#eamPurchaseOrdersBody').closest('.eam-procurement-page').hidden,false);
 }finally{await settle();await settle();w.close();}
});
