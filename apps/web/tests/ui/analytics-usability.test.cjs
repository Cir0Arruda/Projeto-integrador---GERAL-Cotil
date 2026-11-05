'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),{JSDOM}=require('jsdom'),math=require('../../api/services/analytics/statistics');
const settle=()=>new Promise(resolve=>setImmediate(resolve));
async function setup(query=''){
 const dom=new JSDOM(fs.readFileSync('app/analytics.html','utf8'),{url:'https://astha.test/app/analytics.html'+query,runScripts:'outside-only'}),w=dom.window,d=w.document,calls=[];
 const study={id:'study',name:'Minha análise',question:'Minha pergunta',versions:[],jobs:[]};let snapshot,job;
 w.Auth={requireAuth:()=>true,getUser:()=>({role:'manager'})};w.AppSidebar={renderApplicationBrand:()=>{}};w.ProfileAvatar={render:()=>{}};w.HTMLElement.prototype.scrollIntoView=()=>{};
 w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};w.HTMLDialogElement.prototype.close=function(){this.open=false;this.dispatchEvent(new w.Event('close'));};
 w.API={get:async url=>({success:true,data:url.endsWith('/catalog')?{execution_enabled:true,imports_enabled:true}:url.endsWith('/studies')?{studies:[study]}:url.endsWith('/draft')?{version:0,draft:null}:url.includes('/snapshots/')?snapshot:url.includes('/jobs/')?job:study}),request:async()=>({success:true,data:{version:1}}),post:async(url,body)=>{calls.push({url,body});if(url==='/analytics/studies'){study.name=body.name;study.question=body.question;return {success:true,data:{id:study.id}};}if(url.endsWith('/snapshots')){snapshot={id:'v1',version:1,row_count:body.rows.length,dataset:body};study.versions=[snapshot];return{success:true,data:snapshot};}if(url.endsWith('/jobs')){job={id:'job',status:'completed',snapshot_id:'v1',method:body.method,result:{method:body.method,variable:snapshot.dataset.variable,result:math.descriptive(snapshot.dataset.rows.map(row=>row.value))}};study.jobs=[job];return{success:true,data:{id:'job'}};}return{success:true,data:{}};}};
 for(const file of ['analytics-imports.js','analytics-sources.js','analytics-manual.js','industrial-analytics.js'])w.eval(fs.readFileSync('app/js/'+file,'utf8'));await settle();await settle();return{w,d,calls,study};
}
function click(d,text,scope=d){const b=[...scope.querySelectorAll('button')].find(node=>node.textContent===text);assert.ok(b,text);b.click();}

test('guided entry reaches a saved statistical result from pasted numbers without a technical setup',async()=>{
 const {w,d,calls}=await setup();try{
  assert.equal(d.querySelectorAll('#analyticsContext .analytics-start-card').length,3);assert.equal(d.getElementById('studyWorkspace').hidden,true);
  click(d,'Digitar ou colar dados');const create=d.getElementById('studyForm');create.elements.name.value='Temperaturas';create.dispatchEvent(new w.Event('submit',{cancelable:true}));await settle();await settle();
  assert.equal(d.getElementById('dataDialog').open,true);assert.equal(calls[0].body.question,'Analisar os dados de Temperaturas');
  const form=d.getElementById('dataForm');form.elements.variable.value='Temperatura';form.elements.unit.value='°C';d.getElementById('manualPasteValues').value='10\n20\n\n0\n30';click(d,'Adicionar valores à tabela');
  assert.equal(d.getElementById('manualDataTable').hidden,false);form.dispatchEvent(new w.Event('submit',{cancelable:true}));assert.equal(d.getElementById('manualReviewDialog').open,true);
  const review=d.getElementById('manualReviewForm');review.elements.confirm.checked=true;review.dispatchEvent(new w.Event('submit',{cancelable:true}));await settle();await settle();
  const saved=calls.find(call=>call.url.endsWith('/snapshots'));assert.deepEqual(Array.from(saved.body.rows,row=>row.value),[10,20,null,0,30]);assert.equal(d.getElementById('workspaceAnalysis').hidden,false);assert.equal(d.getElementById('studyLibrary').hidden,true);
  click(d,'Executar análise');d.getElementById('runForm').dispatchEvent(new w.Event('submit',{cancelable:true}));await settle();await settle();assert.equal(d.getElementById('workspaceResults').hidden,false);assert.match(d.getElementById('analyticsOutput').textContent,/Média15/);assert.equal(new URL(w.location).searchParams.get('view'),'results');
  click(d,'← Minhas análises');assert.equal(d.getElementById('studyLibrary').hidden,false);assert.equal(d.getElementById('studyWorkspace').hidden,true);assert.equal(new URL(w.location).searchParams.get('study'),null);
 }finally{w.close();}
});

test('paste is atomic, accepts decimal comma and refuses hidden uncommitted data',async()=>{
 const {w,d,calls}=await setup();try{
  w.AnalyticsManual.open('study',()=>{});await settle();const form=d.getElementById('dataForm');form.elements.variable.value='Leitura';form.elements.unit.value='mm';
  const paste=d.getElementById('manualPasteValues');paste.value='1,5\n0\n-2.5';click(d,'Adicionar valores à tabela');assert.deepEqual([...d.querySelectorAll('#dataRows tr')].map(row=>row.querySelectorAll('input')[1].value),['1.5','0','-2.5']);
  paste.value='9\n<img src=x onerror=bad()>';click(d,'Adicionar valores à tabela');assert.equal(d.querySelectorAll('#dataRows tr').length,3);assert.match(d.getElementById('manualPasteFeedback').textContent,/linha 2/);assert.equal(d.querySelector('#dataRows img'),null);
  form.dispatchEvent(new w.Event('submit',{cancelable:true}));assert.equal(d.getElementById('manualReviewDialog').open,false);assert.equal(calls.length,0);assert.match(form.querySelector('[data-feedback]').textContent,/números que você colou/);
  d.getElementById('dataDialog').close();w.AnalyticsManual.open('other',()=>{});assert.equal(paste.value,'');d.getElementById('dataDialog').close();w.AnalyticsManual.open('study',()=>{});assert.equal(paste.value,'9\n<img src=x onerror=bad()>');
 }finally{w.close();}
});

test('library search, direct page addresses and Back/Forward retain the selected stage',async()=>{
 const {w,d}=await setup('?study=study&view=analysis');try{
  assert.equal(d.getElementById('workspaceAnalysis').hidden,false);assert.match(d.getElementById('workspaceAnalysis').textContent,/Adicione e confira/);
  click(d,'← Minhas análises');d.getElementById('studySearch').value='não existe';d.getElementById('studySearch').dispatchEvent(new w.Event('input'));assert.equal(d.getElementById('studySearchEmpty').hidden,false);
  d.getElementById('studySearch').value='Minha';d.getElementById('studySearch').dispatchEvent(new w.Event('input'));assert.equal(d.querySelector('[data-study-id]').hidden,false);
  w.history.replaceState(null,'','?study=study&view=results');w.dispatchEvent(new w.PopStateEvent('popstate'));await settle();await settle();assert.equal(d.getElementById('workspaceResults').hidden,false);assert.equal(d.getElementById('workspaceAnalysis').hidden,true);
 }finally{w.close();}
});

test('file selection identifies CSV separator and suggests only recognizable columns',async()=>{
 const {w,d}=await setup();try{
  w.API.get=async()=>({success:true,data:{imports:[]}});w.API.request=async()=>({success:true,data:{id:'import',row_count:2,columns:['codigo','valor'],preview:[['A','1.5'],['B','0']],origin:'medicoes',format:'csv'}});
  w.AnalyticsImports.open('study',()=>{},true);await settle();
  const form=d.getElementById('importUpload'),file=new w.File(['codigo,valor\nA,1.5\nB,0'],'medicoes.csv',{type:'text/csv'});Object.defineProperty(form.elements.file,'files',{value:[file],configurable:true});form.elements.file.dispatchEvent(new w.Event('change'));
  await new Promise(resolve=>setTimeout(resolve,25));assert.equal(form.elements.origin.value,'medicoes');assert.equal(form.elements.delimiter.value,',');form.reportValidity=()=>true;form.dispatchEvent(new w.Event('submit',{cancelable:true}));await new Promise(resolve=>setTimeout(resolve,25));
  const mapping=d.getElementById('importMapping');assert.equal(mapping.elements.subject_column.value,'codigo');assert.equal(mapping.elements.value_column.value,'valor');assert.equal(mapping.elements.unit.value,'');assert.equal(d.getElementById('publishImport').disabled,true);
 }finally{w.close();}
});

test('downloaded CSV templates are accepted by the real parser and never publish sample rows',async()=>{
 const {w,d,calls}=await setup();try{
  const blobs=[],names=[];w.URL.createObjectURL=blob=>{blobs.push(blob);return 'blob:test';};w.URL.revokeObjectURL=()=>{};w.HTMLAnchorElement.prototype.click=function(){names.push(this.download);};
  d.getElementById('downloadMeasurementTemplate').click();d.getElementById('downloadLifeTemplate').click();assert.equal(blobs.length,2);
  const read=blob=>new Promise(resolve=>{const reader=new w.FileReader();reader.onload=()=>resolve(reader.result);reader.readAsText(blob);});
  const {parseFile}=require('../../api/services/analytics/file-parser');for(let i=0;i<blobs.length;i++){const text=await read(blobs[i]),table=parseFile({format:'csv',delimiter:';',content:Buffer.from(text).toString('base64')});assert.ok(table.rows.length>=2);assert.equal(table.columns[0],'registro');}
  assert.deepEqual(names,['astha-modelo-medicoes.csv','astha-modelo-vida-util.csv']);assert.equal(calls.length,0);
 }finally{w.close();}
});

test('ASTHA source starts with a recent period and selects only a single authorized equipment and metric',async()=>{
 const {w,d}=await setup();try{
  w.API.get=async url=>({success:true,data:url.includes('/metrics?')?{metrics:[{metric_code:'temperature',unit:'°C'}]}:{assets:[{asset_code:'P-01',name:'Bomba'}],has_more:false}});
  w.AnalyticsSources.open('study',()=>{});await settle();await settle();const form=d.getElementById('sourceForm');assert.equal(form.elements.asset_code.value,'P-01');assert.equal(JSON.parse(form.elements.metric.value).metric_code,'temperature');assert.ok(form.elements.from.value);assert.ok(form.elements.through.value);
  d.getElementById('sourceLast7').click();const days=(Date.parse(form.elements.through.value)-Date.parse(form.elements.from.value))/86400000;assert.equal(days,6);assert.equal(d.getElementById('publishSource').disabled,true);
  d.getElementById('sourceDialog').close();w.AnalyticsSources.open('study',()=>{},{asset_code:'OUTSIDE-ACCOUNT',from:'2026-09-01',through:'2026-09-30'});await settle();assert.equal(form.elements.asset_code.value,'');assert.equal(form.elements.from.value,'2026-09-01');assert.equal([...form.elements.asset_code.options].some(option=>option.value==='OUTSIDE-ACCOUNT'),false);
 }finally{w.close();}
});
