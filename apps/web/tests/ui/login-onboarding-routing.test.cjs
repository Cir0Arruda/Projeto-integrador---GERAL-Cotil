'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
async function navigate(setupDone,saved){
 const handlers={},assigned=[],local=new Map(),session=new Map(saved?[['ASTHA_redirect',saved]]:[]);
 const store=map=>({getItem:key=>map.get(key)||null,setItem:(key,value)=>map.set(key,value),removeItem:key=>map.delete(key)});
 const button={disabled:false},password={value:'Synthetic test password',type:'password'};
 const nodes={loginForm:{elements:{email:{value:'qa@example.invalid'}},querySelector:()=>button,addEventListener:(event,fn)=>handlers[event]=fn},password,togglePassword:{addEventListener(){}},'login-error-msg':{hidden:true}};
 const context=vm.createContext({document:{getElementById:id=>nodes[id]},localStorage:store(local),sessionStorage:store(session),URL,URLSearchParams,
  location:{origin:'http://localhost',href:'http://localhost/app/login.html',hash:'',assign:path=>assigned.push(path)},
  API:{post:async()=>({success:true,token:'synthetic',setup_done:setupDone,user:{id:1}})}});
 vm.runInContext(fs.readFileSync('app/js/login-entry.js','utf8'),context);
 await handlers.submit({preventDefault(){}});return assigned;
}
test('local login honors pending setup before any remembered app route',async()=>{
 assert.deepEqual(await navigate(false,'/app/sistema.html?tab=estoque'),['./onboarding.html']);
 assert.deepEqual(await navigate(true,'/app/sistema.html?tab=estoque'),['/app/sistema.html?tab=estoque']);
 assert.deepEqual(await navigate(true,'https://example.invalid/steal'),['./home.html']);
});
