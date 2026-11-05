'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('jsdom');
const read=path=>fs.readFileSync(path,'utf8');
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function delayedResponse(status=200,value={private:'previous-account'}) {
  let begin,finish;
  const entered=new Promise(resolve=>begin=resolve);
  const body=()=>{begin();return new Promise(resolve=>finish=()=>resolve(value));};
  return {entered,finish:()=>finish(),response:{ok:status===200,status,json:body,text:body}};
}

test('shared API rejects a previous session after delayed JSON or text decoding',async()=>{
  for(const [status,text] of [[200,false],[401,false],[200,true]]) {
    const dom=new JSDOM('',{url:'https://app.example.invalid/app/home.html',runScripts:'outside-only'}),w=dom.window;
    try {
      w.localStorage.setItem('astha_token','old-session');
      const delayed=delayedResponse(status,text?'old-private-csv':{private:'old-account'});
      w.fetch=async()=>delayed.response;
      w.eval(read('app/js/api.js')+'\nwindow.testAPI=API;');
      const request=w.testAPI.request('/materials',{method:'GET',...(text?{responseType:'text'}:{})});
      await delayed.entered;w.localStorage.setItem('astha_token','new-session');delayed.finish();
      const result=await request;
      assert.equal(result.success,false);assert.equal(result.status,409);assert.equal(result.data,undefined);
      assert.equal(w.localStorage.getItem('astha_token'),'new-session');
    } finally { w.close(); }
  }
});

test('an expired-session redirect cannot redirect a newer login or suppress its later expiry',async()=>{
  const values=new Map([['astha_token','expired-one']]),timers=[];
  const storage={getItem:key=>values.get(key)||null,setItem:(key,value)=>values.set(key,value),removeItem:key=>values.delete(key)};
  const location={protocol:'https:',hostname:'app.example.invalid',port:'',pathname:'/app/home.html',search:'',href:'unchanged'};
  const context={localStorage:storage,sessionStorage:storage,window:{location},document:{querySelector:()=>null},AbortController,console,
    setTimeout:(fn,delay)=>{if(delay===1200)timers.push(fn);return 1;},clearTimeout:()=>{},
    fetch:async()=>({ok:false,status:401,json:async()=>({error:'Expired'})})};
  vm.runInNewContext(read('app/js/api.js')+'\nthis.testAPI=API;',context);
  await context.testAPI.get('/materials');assert.equal(timers.length,1);
  storage.setItem('astha_token','new-session');timers[0]();
  assert.equal(location.href,'unchanged');assert.equal(storage.getItem('astha_token'),'new-session');
  await context.testAPI.get('/materials');assert.equal(timers.length,2);
  assert.equal(storage.getItem('astha_token'),null);
  timers[1]();assert.equal(location.href,'/app/login.html');
});

async function personal() {
  const dom=new JSDOM(read('app/personal.html'),{url:'https://app.example.invalid/app/personal.html',runScripts:'outside-only'}),w=dom.window;
  w.localStorage.setItem('astha_token','old-session');
  w.PersonalCatalog=require('../../app/js/personal-catalog');
  w.PersonalContent={init:hooks=>w.testPersonalHooks=hooks,refresh:()=>{}};
  w.PersonalOrganizer={init:()=>{},render:()=>{}};
  w.ProfileAvatar={render:()=>{}};
  w.fetch=async url=>({ok:true,status:200,json:async()=>url==='/api/workspace/context'?{type:'personal'}:url==='/api/auth/me'?{name:'Fixture',setup_done:true}:[]});
  w.eval(read('app/js/personal.js'));await tick();await tick();
  return {dom,w};
}
test('personal module rejects delayed private records and cannot clear a newer login on old 401',async()=>{
  for(const status of [200,401]) {
    const {w}=await personal();
    try {
      const delayed=delayedResponse(status);
      w.fetch=async()=>delayed.response;
      const pending=w.testPersonalHooks.api('/personal/spaces');
      await delayed.entered;w.localStorage.setItem('astha_token','new-session');delayed.finish();
      await assert.rejects(pending,/sessão mudou/i);
      assert.equal(w.localStorage.getItem('astha_token'),'new-session');
    } finally { w.close(); }
  }
});

async function account() {
  const dom=new JSDOM('<main><div id="accountPanel"></div></main>',{url:'https://app.example.invalid/app/account.html',runScripts:'outside-only'}),w=dom.window;
  w.localStorage.setItem('astha_token','old-session');
  w.fetch=async url=>url==='./account-panel.html'?{ok:true,text:async()=>read('app/account-panel.html')}:
    {ok:true,status:200,json:async()=>url.endsWith('/sessions')?[]:{email:'fixture@example.invalid',provider:'local',canChangeCredentials:true}};
  w.eval(read('app/js/account-settings.js'));await w.AccountSettings.refresh();
  return {dom,w};
}
test('account context never publishes delayed previous-user email or expires a newer session',async()=>{
  for(const status of [200,401]) {
    const {w}=await account();
    try {
      const delayed=delayedResponse(status,{email:'previous-private@example.invalid'});
      w.fetch=async url=>url==='/api/account'?delayed.response:{ok:true,status:200,json:async()=>[]};
      const pending=w.AccountSettings.refresh();
      await delayed.entered;w.localStorage.setItem('astha_token','new-session');delayed.finish();
      await assert.rejects(pending,/sessão mudou/i);
      assert.equal(w.document.getElementById('accountEmail').textContent,'fixture@example.invalid');
      assert.equal(w.localStorage.getItem('astha_token'),'new-session');
    } finally { w.close(); }
  }
});
test('account profile export cannot download previous-user data after session replacement',async()=>{
  const {w}=await account();
  try {
    const delayed=delayedResponse(200,{email:'previous-private@example.invalid'});
    let downloads=0;w.URL.createObjectURL=()=>{downloads++;return 'blob:https://app.example.invalid/fixture';};
    w.URL.revokeObjectURL=()=>{};w.fetch=async()=>delayed.response;
    w.document.getElementById('exportAccountData').click();
    await delayed.entered;w.localStorage.setItem('astha_token','new-session');delayed.finish();await tick();
    assert.equal(downloads,0);assert.match(w.document.getElementById('accountNotice').textContent,/sessão mudou/i);
    assert.equal(w.localStorage.getItem('astha_token'),'new-session');
  } finally { w.close(); }
});

test('malformed account responses cannot expose parser excerpts of private response bodies',async()=>{
  const {w}=await account();
  try {
    w.fetch=async()=>({ok:true,status:200,json:async()=>{throw new SyntaxError('Unexpected token SYNTHETIC_PRIVATE_ACCOUNT_DATA');}});
    await assert.rejects(w.AccountSettings.refresh(),error=>
      error.message==='O servidor não respondeu. Tente novamente.');
    assert.equal(w.localStorage.getItem('astha_token'),'old-session');
  } finally { w.close(); }
});

test('a confirmed mutation forces a fresh read instead of sharing a pre-write stock request',async()=>{
  for(const writeStatus of [201,409]) {
    const dom=new JSDOM('',{url:'https://app.example.invalid/app/home.html',runScripts:'outside-only'}),w=dom.window;
    try {
      let reads=0,finishOld;
      w.fetch=async(_url,options)=>options.method==='GET'?(++reads===1?
        new Promise(resolve=>finishOld=()=>resolve({ok:true,status:200,json:async()=>({quantity:1})})):
        {ok:true,status:200,json:async()=>({quantity:2})}):
        {ok:writeStatus===201,status:writeStatus,json:async()=>writeStatus===201?{quantity:2}:{error:'Conflict'}};
      w.eval(read('app/js/api.js')+'\nwindow.testAPI=API;');
      const old=w.testAPI.get('/materials');
      const write=await w.testAPI.post('/movements/entry',{quantity:1});
      assert.equal(write.success,writeStatus===201);
      const fresh=w.testAPI.get('/materials');
      if(writeStatus===201){assert.notEqual(fresh,old);assert.equal(reads,2);}
      else {assert.equal(fresh,old);assert.equal(reads,1);}
      finishOld();
      assert.equal((await fresh).data.quantity,writeStatus===201?2:1);
      assert.equal((await old).data.quantity,writeStatus===201?2:1);
    } finally { w.close(); }
  }
});
