'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('jsdom');

test('a failed assistant query restores its text without overwriting a newer draft',async()=>{
 const dom=new JSDOM('<body></body>',{url:'http://qa.invalid/app/home.html',runScripts:'outside-only'}),w=dom.window;try{w.localStorage.setItem('astha_token','qa');w.HTMLElement.prototype.scrollIntoView=()=>{};let finish;w.API={post:()=>new Promise(resolve=>{finish=resolve;})};w.eval(fs.readFileSync('app/js/operational-assistant.js','utf8'));const form=w.document.querySelector('form'),input=w.document.querySelector('textarea');
  for(const nextDraft of ['', 'Minha próxima pergunta']){input.value='Materiais no mínimo';form.dispatchEvent(new w.Event('submit',{cancelable:true}));input.value=nextDraft;finish({success:false,error:'Falha controlada'});await new Promise(r=>setImmediate(r));assert.equal(input.value,nextDraft||'Materiais no mínimo');assert.equal(w.document.querySelector('.assistant-send').disabled,false);}
 }finally{w.close();}
});
test('widget requires a session, renders untrusted responses as text, clears and closes',async()=>{
 const dom=new JSDOM('<!doctype html><body></body>',{url:'http://localhost/app/home.html',runScripts:'outside-only'}),w=dom.window;
 try{
  const code=fs.readFileSync('app/js/operational-assistant.js','utf8');w.API={post:async()=>({success:true,data:{intent:'stock',mode:'local',notice:'<img src=x onerror=alert(1)>',summary:{count:1,critical:1,zero:0},refs:[],sources:[{ref:1,kind:'stock',id:1,label:'<script>throw 1</script>',quantity:2,minimum:3}]}})};
  w.eval(code);assert.equal(w.document.querySelector('#asthaAssistant'),null);
  w.localStorage.setItem('astha_token','test-only');w.HTMLElement.prototype.scrollIntoView=()=>{};w.eval(code);
  const panel=w.document.querySelector('#assistantPanel'),launcher=w.document.querySelector('.assistant-launcher');assert.equal(panel.hidden,true);launcher.click();assert.equal(panel.hidden,false);
  w.document.querySelector('textarea').value='Estoque';w.document.querySelector('form').dispatchEvent(new w.Event('submit',{cancelable:true}));await new Promise(r=>setImmediate(r));
  assert.equal(w.document.querySelector('.assistant-messages img'),null);assert.equal(w.document.querySelector('.assistant-messages script'),null);assert.ok(w.document.querySelector('.assistant-messages').textContent.includes('<script>'));
  w.document.querySelector('.assistant-clear').click();assert.equal(w.document.querySelector('.assistant-messages').children.length,0);
  w.document.querySelector('.assistant-close').click();assert.equal(panel.hidden,true);assert.equal(launcher.getAttribute('aria-expanded'),'false');
 }finally{w.close();}
});
test('assistant uses applied dashboard filters, renders BRL values and basic fields as text',async()=>{
 const dom=new JSDOM('<!doctype html><body><section class="stock-insights"><input type="date" value="2030-01-01"></section></body>',{url:'http://localhost/app/home.html?view=stocks',runScripts:'outside-only'}),w=dom.window,requests=[];
 try{
  const panel=w.document.querySelector('.stock-insights');panel.dataset.assistantContext=JSON.stringify({from:'2026-09-15',to:'2026-10-14',warehouseIds:[7,8]});panel.getClientRects=()=>[{width:500,height:500}];
  w.localStorage.setItem('astha_token','test-only');w.API={post:async(url,body)=>{requests.push(body);return {success:true,data:{mode:'gemini',message:'Entradas consultadas.',sources:[{ref:'R1',kind:'movements',label:'QA-01',name:'<img src=x>',quantity:2,type:'entrada',unitPrice:6875,movementValue:13750,currency:'BRL',valuation:'recorded',at:'2026-10-14 10:00:00'}],queries:[{module:'movements',scope:'dashboard_warehouses',from:'2026-09-15',to:'2026-10-14',summary:{types:{entrada:{valueByCurrency:[{currency:'BRL',value:13750}]},saida:{valueByCurrency:[]}},estimated:0}}]}};}};
  w.eval(fs.readFileSync('app/js/operational-assistant.js','utf8'));
  const send=async()=>{w.document.querySelector('textarea').value='Qual o valor das entradas no período?';w.document.querySelector('.assistant-form').dispatchEvent(new w.Event('submit',{cancelable:true}));await new Promise(r=>setImmediate(r));};
  await send();assert.deepEqual(JSON.parse(JSON.stringify(requests[0].viewContext)),{from:'2026-09-15',to:'2026-10-14',warehouseIds:[7,8]});assert.equal(requests[0].from,undefined);
  const answer=w.document.querySelector('.assistant-answer');assert.match(answer.textContent,/13\.750,00/);assert.match(answer.textContent,/6\.875,00/);assert.match(answer.textContent,/estoques selecionados no painel/);assert.equal(answer.querySelector('img'),null);
  w.document.querySelector('.assistant-form [name=from]').value='2026-10-01';w.document.querySelector('[name=allStocks]').checked=true;await send();assert.equal(requests[1].from,'2026-10-01');assert.equal(requests[1].viewContext.warehouseIds,undefined);
 }finally{w.close();}
});
test('shows pending progress, types safely, supports skip and reduced motion, and scopes stock requests',async()=>{
 const dom=new JSDOM('<!doctype html><body><select id="warehouseStockSelect"><option value="7" selected>Estoque aberto</option></select></body>',{url:'http://localhost/app/sistema.html?tab=estoque',runScripts:'outside-only',pretendToBeVisual:true}),w=dom.window,frames=new Map(),requests=[];
 let frameId=0,complete,fail,reduced=false;
 try{
  w.requestAnimationFrame=cb=>{frames.set(++frameId,cb);return frameId;};w.cancelAnimationFrame=id=>frames.delete(id);
  w.matchMedia=()=>({matches:reduced,addEventListener(){},removeEventListener(){}});
  w.localStorage.setItem('astha_token','test-only');w.HTMLElement.prototype.scrollIntoView=()=>{};
  w.API={post:async(url,body)=>{requests.push(body);return new Promise((resolve,reject)=>{complete=resolve;fail=reject;});}};
  w.eval(fs.readFileSync('app/js/operational-assistant.js','utf8'));w.document.querySelector('.assistant-launcher').click();
  const submit=()=>{w.document.querySelector('textarea').value='Materiais no mínimo';w.document.querySelector('form').dispatchEvent(new w.Event('submit',{cancelable:true}));};
  const message='Um resultado com contexto e fontes. '.repeat(7)+'👋 <script>não executar</script>';
  const data={message,mode:'gemini',refs:['R1'],sources:[{ref:'R1',kind:'stock',label:'QA-VISIBLE',quantity:1,minimum:5}],queries:[{module:'stock',scope:'selected_warehouse'}]};
  submit();assert.equal(requests[0].warehouseId,7);assert.equal(w.document.querySelector('.assistant-progress').hidden,false);assert.match(w.document.querySelector('.assistant-progress-label').textContent,/Consultando/);
  complete({success:true,data});await new Promise(r=>setImmediate(r));
  const article=w.document.querySelector('.assistant-answer'),text=w.document.querySelector('.assistant-response-text');assert.equal(article.getAttribute('aria-busy'),'true');assert.equal(text.textContent,'');assert.match(w.document.querySelector('.assistant-progress-label').textContent,/Escrevendo/);
  const tick=now=>{const callbacks=[...frames.values()];frames.clear();callbacks.forEach(cb=>cb(now));};tick(0);tick(120);
  assert.ok(text.textContent.length>0&&text.textContent.length<message.length);assert.equal(w.document.querySelector('.assistant-send').disabled,true);
  w.document.querySelector('.assistant-skip').click();await new Promise(r=>setImmediate(r));assert.equal(text.textContent,message);assert.equal(article.hasAttribute('aria-busy'),false);assert.equal(frames.size,0);assert.equal(w.document.querySelector('.assistant-progress').hidden,true);assert.equal(w.document.querySelector('.assistant-send').disabled,false);assert.equal(w.document.querySelector('.assistant-answer script'),null);
  reduced=true;w.document.querySelector('[name=allStocks]').checked=true;submit();assert.equal(requests[1].warehouseId,undefined);complete({success:true,data});await new Promise(r=>setImmediate(r));assert.equal(frames.size,0);assert.equal(w.document.querySelectorAll('.assistant-response-text')[1].textContent,message);
  submit();fail(Error('offline'));await new Promise(r=>setImmediate(r));assert.equal(w.document.querySelector('.assistant-progress').hidden,true);assert.equal(w.document.querySelector('.assistant-send').disabled,false);assert.match(w.document.querySelector('.assistant-error').textContent,/conectar/);
 }finally{w.close();}
});
test('contextual widget sends conversation ID, renders asset cards safely and clears server history',async()=>{
 const dom=new JSDOM('<!doctype html><body></body>',{url:'http://localhost/app/home.html',runScripts:'outside-only'}),w=dom.window,requests=[],deleted=[];
 try{
  const id='12345678-1234-1234-1234-123456789abc';w.localStorage.setItem('astha_token','test-only');w.HTMLElement.prototype.scrollIntoView=()=>{};
  w.API={post:async(url,body)=>{requests.push(body);return {success:true,data:{conversationId:id,mode:'gemini',message:'Consulte [R1]. <script>unsafe</script>',refs:['R1'],sources:[{kind:'assets',ref:'R1',label:'QA-01',name:'<img src=x>',status:'maintenance',criticality:'high'}],queries:[]}};},delete:async url=>{deleted.push(url);return {success:true};}};
  w.eval(fs.readFileSync('app/js/operational-assistant.js','utf8'));
  const send=async question=>{w.document.querySelector('textarea').value=question;w.document.querySelector('form').dispatchEvent(new w.Event('submit',{cancelable:true}));await new Promise(r=>setImmediate(r));};
  await send('Quais os ativos?');await send('E os que estão em manutenção?');assert.equal(requests[1].conversationId,id);
  assert.equal(w.document.querySelector('.assistant-messages img'),null);assert.equal(w.document.querySelector('.assistant-messages script'),null);assert.match(w.document.querySelector('.assistant-messages').textContent,/Em manutenção/);
  w.document.querySelector('.assistant-clear').click();await new Promise(r=>setImmediate(r));assert.deepEqual(deleted,['/assistant/conversations/'+id]);
  await send('Quais os ativos?');assert.equal(requests[2].conversationId,undefined);
 }finally{w.close();}
});
