const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {JSDOM}=require('jsdom');
const root=path.resolve(__dirname,'../..');const settle=()=>new Promise(resolve=>setImmediate(resolve));
test('operational pages start light before scripts and cannot restore the retired dark theme',()=>{
 const html=fs.readFileSync(path.join(root,'app/sistema.html'),'utf8');
 const dom=new JSDOM(html);try{
  assert.equal(dom.window.document.documentElement.classList.contains('light-mode'),true);
  assert.equal(dom.window.document.querySelector('#themeToggle'),null);
  assert.equal(html.includes("getItem('astha_theme')"),false);
  assert.equal(html.includes('function toggleTheme'),false);
 }finally{dom.window.close();}
});
async function setup(liveClock=false){
 const dom=new JSDOM(fs.readFileSync(path.join(root,'app/sistema.html'),'utf8'),{runScripts:'outside-only',url:'http://localhost/app/sistema.html'}),w=dom.window;
 w.Auth={requireAuth:()=>false,getUser:()=>null};w.showToast=()=>{};
 w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};w.HTMLDialogElement.prototype.close=function(){this.open=false;};
 const calls=[],timers=new Map();let timerId=0;if(liveClock){Object.defineProperty(w.document,'hidden',{value:false,configurable:true});w.setTimeout=(fn,ms)=>{timers.set(++timerId,{fn,ms});return timerId;};w.clearTimeout=id=>timers.delete(id);}
 w.API={get:async endpoint=>{calls.push(endpoint);return {success:true,data:endpoint==='/eam/assets'?[{id:11,asset_code:'AT-11',name:'Motor',status:'active'}]:endpoint.includes('/reliability/assets/')?{period:{hours:720},failures:null,corrective_orders:2,downtime_hours:4,availability:null,calendar_availability:716/720,exposure:{unknown_hours:716},mtbf_hours:null,mttr_hours:null,mtws_hours:null,tco:100,warnings:['Sem exposição operacional observada.']}:endpoint.endsWith('/condition')?{rules:[],readings:[],alerts:[]}:[]};},post:async(endpoint,body)=>{calls.push({endpoint,body});return {success:true,data:{id:3}};}};
 w.eval(['security.js','sistema-core.js','eam-ux.js'].map(file=>fs.readFileSync(path.join(root,'app/js',file),'utf8')).join('\n'));
 await settle();return {dom,w,calls,timers};
}

test('reliability fields keep a single visible label after page initialization',async()=>{
 const {dom,w}=await setup();try{for(const id of ['eamReliabilityAsset','eamReliabilityFrom','eamReliabilityTo']){const field=w.document.getElementById(id);assert.equal(field.closest('label').parentElement.closest('label'),null);assert.equal(field.labels.length,1);}}finally{dom.window.close();}
});
test('order creation opens a modal and loads tenant assets directly without procurement requests',async()=>{
 const {dom,w,calls}=await setup();try{
  await w.toggleEamOrderForm(true);
  assert.equal(w.document.querySelector('#eamOrderCreatePanel'),null);
  assert.equal(w.document.querySelector('#eamOrderCreateDialog').open,true);
  assert.equal(w.document.querySelector('#eamOrderAsset').options[1].value,'11');
  assert.deepEqual(calls,['/eam/assets']);
  w.document.querySelector('#eamOrderAsset').value='11';w.document.querySelector('#eamOrderTitle').value='Inspeção';
  w.renderEam=async()=>{};
  await w.createEamWorkOrder({preventDefault(){},target:w.document.querySelector('#eamOrderCreateForm')});
  assert.equal(calls[1].body.asset_id,11);assert.equal(w.document.querySelector('#eamOrderCreateDialog').open,false);
 }finally{dom.window.close();}
});
test('reliability prioritizes real indicators and graphs while editors open in dialogs',async()=>{
 const {dom,w}=await setup();try{
  w.switchEamSection('reliability',w.document.querySelector('[onclick*="reliability"]'));await settle();await settle();
  assert.equal(w.document.querySelector('#eamReliabilityAsset').value,'11');
  assert.ok(w.document.querySelector('#eamReliabilityResult').textContent.includes('Sem dados'));
  assert.ok(w.document.querySelector('#eamReliabilityResult').textContent.includes('Disponibilidade no calendário'));
  assert.ok(w.document.querySelector('#eamReliabilityCharts').textContent.includes('Sem exposição operacional observada.'));
  assert.equal(w.document.querySelectorAll('#eamReliabilityCharts svg').length,1);
  assert.equal(w.document.querySelectorAll('#eam-reliability form').length,1);
  const button=[...w.document.querySelectorAll('.eam-ux-actions button')].find(el=>el.textContent==='Cadastrar limite');button.click();
  assert.equal(w.document.querySelector('#eamConditionRulesDialog').open,true);
  assert.equal(w.document.querySelector('#eamConditionAsset').value,'11');
 }finally{dom.window.close();}
});
test('failed asset loading disables order submission and gives a visible explanation',async()=>{
 const {dom,w}=await setup();try{
  w.API.get=async()=>({success:false,error:'Ativos indisponíveis'});
  await w.toggleEamOrderForm(true);
  assert.equal(w.document.querySelector('#eamOrderCreateForm [type=submit]').disabled,true);
  assert.equal(w.document.querySelector('#eamOrderCreateDialog [role=status]').textContent,'Ativos indisponíveis');
 }finally{dom.window.close();}
});
test('visible reliability refreshes every five seconds, preserves unchanged graphs, stops hidden reads and retains data on error',async()=>{
 const {dom,w,calls,timers}=await setup(true);try{
  const d=w.document;d.getElementById('panel-eam').classList.add('active');w.switchEamSection('reliability',d.querySelector('[onclick*="reliability"]'));await settle();await settle();
  const graph=d.querySelector('#eamReliabilityCharts svg'),count=()=>calls.filter(call=>typeof call==='string'&&call.includes('/reliability/assets/')).length,fire=async()=>{const timer=[...timers.values()].find(t=>t.ms===5000);assert.ok(timer);await timer.fn();await settle();};
  const before=count();await fire();assert.equal(count(),before+1);assert.equal(d.querySelector('#eamReliabilityCharts svg'),graph);assert.match(d.getElementById('eamReliabilityLiveStatus').textContent,/5 s/);
  d.getElementById('eamReliabilityCharts').hidden=true;await fire();assert.equal(count(),before+1);d.getElementById('eamReliabilityCharts').hidden=false;
  w.API.get=async()=>({success:false,error:'Sem conexão'});await fire();assert.equal(d.querySelector('#eamReliabilityCharts svg'),graph);assert.match(d.getElementById('eamReliabilityLiveStatus').textContent,/não foram confirmados/);
  const pause=[...d.querySelectorAll('.eam-live-controls button')][0];pause.click();assert.equal(pause.getAttribute('aria-pressed'),'true');assert.equal(timers.size,0);
 }finally{dom.window.close();}
});
test('background condition and equipment comparison preserve unchanged content and stale errors never erase it',async()=>{
 const {dom,w}=await setup();try{
  await w.EamUx.assets();const d=w.document;d.getElementById('eamConditionAsset').value='11';d.getElementById('eamReliabilityAsset').value='11';
  const comparison={assets:[{asset_code:'AT-11',name:'Motor',corrective_orders:2,downtime_hours:4,calendar_availability:.9,mtbf_hours:12,production_loss_cost:100}]};let failure=false;
  w.API.get=async route=>failure?{success:false,error:'Sem conexão'}:{success:true,data:route.includes('/summary')?comparison:{rules:[],readings:[],alerts:[]}};
  await w.loadEamCondition();const condition=d.getElementById('eamConditionResult').firstElementChild;await w.loadEamCondition({background:true});assert.equal(d.getElementById('eamConditionResult').firstElementChild,condition);
  await w.loadEamReliabilitySummary();const table=d.getElementById('eamReliabilitySummary').firstElementChild;await w.loadEamReliabilitySummary({background:true});assert.equal(d.getElementById('eamReliabilitySummary').firstElementChild,table);assert.match(table.textContent,/Motor/);
  failure=true;await w.loadEamCondition({background:true});await w.loadEamReliabilitySummary({background:true});assert.equal(d.getElementById('eamConditionResult').firstElementChild,condition);assert.equal(d.getElementById('eamReliabilitySummary').firstElementChild,table);assert.match(d.getElementById('eamReliabilityLiveStatus').textContent,/não foram confirmados/);
 }finally{dom.window.close();}
});
