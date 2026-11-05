'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {JSDOM}=require('jsdom'),root=path.resolve(__dirname,'../..');
function setup(){
 const dom=new JSDOM(fs.readFileSync(path.join(root,'app/sistema.html'),'utf8'),{runScripts:'outside-only',url:'http://qa.invalid/app/sistema.html'}),w=dom.window;
 w.Auth={requireAuth:()=>false};w.eval(fs.readFileSync(path.join(root,'app/js/security.js'),'utf8'));w.eval(fs.readFileSync(path.join(root,'app/js/sistema-core.js'),'utf8'));w.eval(fs.readFileSync(path.join(root,'app/js/sistema-features.js'),'utf8'));
 w.eval("materials=[{code:'QA-1',desc:'Material sintético',qty:5}];initAppData=async()=>{};");return{dom,w,d:w.document};
}
test('entry and exit retain three decimal places; a supplied entry price is sent and an empty one is omitted',async()=>{
 const {dom,w,d}=setup();try{
  const calls=[];w.API={post:async(url,body)=>{calls.push({url,body});return{success:true};}};
  for(const [qty,price] of [['1.125','12.34'],['0.125','']]){d.getElementById('entryCode').value='QA-1';d.getElementById('entryQty').value=qty;d.getElementById('entryPrice').value=price;await w.handleEntry({preventDefault(){},target:d.getElementById('entradaForm')});}
  assert.equal(calls[0].body.quantity,1.125);assert.equal(calls[0].body.unit_price,12.34);assert.equal(calls[1].body.quantity,.125);assert.equal(Object.hasOwn(calls[1].body,'unit_price'),false);
  d.getElementById('exitCode').value='QA-1';d.getElementById('exitQty').value='0.375';await w.handleExit({preventDefault(){},target:d.getElementById('saidaForm')});assert.equal(calls[2].body.quantity,.375);
  for(const id of ['entryQty','exitQty']){const input=d.getElementById(id);input.value='.125';assert.equal(input.validity.valid,true);}
 }finally{dom.window.close();}
});
test('a pending stock submission disables its button and prevents a duplicate movement',async()=>{
 const {dom,w,d}=setup();try{let finish,calls=0;w.API={post:()=>{calls++;return new Promise(resolve=>{finish=resolve;});}};d.getElementById('entryCode').value='QA-1';d.getElementById('entryQty').value='1.125';const form=d.getElementById('entradaForm'),event={preventDefault(){},target:form};
  const first=w.handleEntry(event);assert.equal(form.querySelector('button').disabled,true);await w.handleEntry(event);assert.equal(calls,1);finish({success:true});await first;assert.equal(form.querySelector('button').disabled,false);
 }finally{dom.window.close();}
});
test('invalid fractions and insufficient stock never reach the movement API',async()=>{
 const {dom,w,d}=setup();try{let calls=0;w.API={post:async()=>{calls++;return{success:true};}};d.getElementById('exitCode').value='QA-1';for(const qty of ['-1','0','0.0001','6']){d.getElementById('exitQty').value=qty;await w.handleExit({preventDefault(){},target:d.getElementById('saidaForm')});}assert.equal(calls,0);
 }finally{dom.window.close();}
});
test('plain notes including JSON null and arrays cannot break stock rendering',()=>{
 const {dom,w}=setup();try{for(const notes of ['null','[1,2]','"observação"','texto']){w.testMaterial={notes};w.eval('window.mappedMaterial=mapMaterialToFrontend(testMaterial)');assert.equal(w.mappedMaterial.plainNotes,notes);}}finally{dom.window.close();}
});
test('a slower previous warehouse load cannot replace the newly selected stock',async()=>{
 const dom=new JSDOM('',{runScripts:'outside-only',url:'http://qa.invalid/app/sistema.html?warehouse=1'}),w=dom.window;try{
  w.Auth={requireAuth:()=>false,canManageUsers:()=>false,getUser:()=>null};
  w.eval(fs.readFileSync(path.join(root,'app/js/sistema-core.js'),'utf8')+'\nrenderWarehouseTabs=renderDashboard=renderStock=renderReports=renderComponents=renderUsers=()=>{};window.runLoad=initAppData;window.chooseWarehouse=selectWarehouse;window.stockState=()=>({currentWarehouseId,codes:materials.map(m=>m.code)});');
  let releaseOld,oldRequested;const waiting=new Promise(resolve=>{oldRequested=resolve;});w.API={get:async url=>{if(url==='/warehouse/tabs')return{success:true,data:[{id:1},{id:2}]};if(url==='/materials?warehouse_id=1'){oldRequested();return new Promise(resolve=>{releaseOld=resolve;});}return{success:true,data:url.startsWith('/materials')?[{code:'SECOND',quantity:'2.125'}]:[]};}};
  const old=w.runLoad();await waiting;await w.chooseWarehouse(2);releaseOld({success:true,data:[{code:'FIRST',quantity:999}]});await old;const snapshot=w.stockState();assert.equal(snapshot.currentWarehouseId,2);assert.deepEqual(Array.from(snapshot.codes),['SECOND']);
 }finally{dom.window.close();}
});
