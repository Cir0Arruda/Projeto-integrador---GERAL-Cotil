'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),{JSDOM}=require('jsdom');
const settle=()=>new Promise(resolve=>setImmediate(resolve));
async function boot(available=true){
 const dom=new JSDOM(fs.readFileSync('app/recover.html','utf8'),{url:'http://localhost/app/recover.html',runScripts:'outside-only'}),w=dom.window,calls=[];
 w.fetch=async(url,options={})=>{calls.push({url,options});return{ok:true,json:async()=>url.endsWith('recovery-options')?{emailRecoveryAvailable:available}:{message:'Se houver uma conta, você receberá o código.'}};};
 w.eval(fs.readFileSync('app/js/account-recovery.js','utf8'));await settle();return{dom,w,calls};
}
test('disabled email service keeps saved-code recovery available',async()=>{
 const {dom,w}=await boot(false);try{assert.equal(w.document.getElementById('recoveryEmailSection').hidden,true);assert.equal(w.document.getElementById('recoveryEmailUnavailable').hidden,false);assert.equal(w.document.getElementById('recoverAccountForm').hidden,false);}finally{dom.window.close();}
});
test('email request uses the public endpoint once, shows progress, and moves focus to code',async()=>{
 const {dom,w,calls}=await boot();try{
  let resolve;w.fetch=async(url,options)=>{calls.push({url,options});return new Promise(r=>{resolve=r;});};
  const form=w.document.getElementById('requestRecoveryEmailForm');form.elements.email.value='recipient@example.invalid';
  form.dispatchEvent(new w.Event('submit',{cancelable:true}));form.dispatchEvent(new w.Event('submit',{cancelable:true}));
  assert.equal(form.querySelector('button').disabled,true);assert.equal(form.getAttribute('aria-busy'),'true');assert.equal(calls.filter(c=>c.options.method==='POST').length,1);
  resolve({ok:true,json:async()=>({message:'<img src=x> Solicitação recebida.'})});await settle();
  assert.equal(form.querySelector('button').disabled,false);assert.equal(form.hasAttribute('aria-busy'),false);
  assert.equal(w.document.getElementById('recoverAccountForm').elements.email.value,'recipient@example.invalid');assert.equal(w.document.activeElement.name,'code');
  assert.equal(w.document.getElementById('recoveryEmailNotice').querySelector('img'),null);assert.match(w.document.getElementById('recoveryEmailNotice').textContent,/<img/);
  const request=calls.find(c=>c.options.method==='POST');assert.equal(request.url,'/api/account/recover/email');assert.deepEqual(JSON.parse(request.options.body),{email:'recipient@example.invalid'});
 }finally{dom.window.close();}
});
test('send failure re-enables the request and preserves manual recovery',async()=>{
 const {dom,w}=await boot();try{w.fetch=async()=>({ok:false,json:async()=>({error:'Envio indisponível.'})});const form=w.document.getElementById('requestRecoveryEmailForm');form.elements.email.value='recipient@example.invalid';form.dispatchEvent(new w.Event('submit',{cancelable:true}));await settle();assert.equal(form.querySelector('button').disabled,false);assert.equal(w.document.getElementById('recoverAccountForm').hidden,false);assert.equal(w.document.getElementById('recoveryEmailNotice').textContent,'Envio indisponível.');}finally{dom.window.close();}
});
test('late email capability response cannot reopen recovery after a successful reset',async()=>{
 const dom=new JSDOM(fs.readFileSync('app/recover.html','utf8'),{url:'http://localhost/app/recover.html',runScripts:'outside-only'}),w=dom.window;let options;
 try{
  w.fetch=async url=>url.endsWith('recovery-options')?new Promise(resolve=>{options=resolve;}):{ok:true,json:async()=>({message:'Senha redefinida.'})};
  w.eval(fs.readFileSync('app/js/account-recovery.js','utf8'));
  const form=w.document.getElementById('recoverAccountForm');form.elements.email.value='synthetic@example.invalid';form.elements.code.value='abcdefghijklmnopqrstuv';form.elements.new_password.value=form.elements.confirm_password.value='Synthetic recovery password';
  form.dispatchEvent(new w.Event('submit',{cancelable:true}));await settle();
  options({ok:true,json:async()=>({emailRecoveryAvailable:true})});await settle();
  assert.equal(form.hidden,true);assert.equal(w.document.getElementById('recoveryEmailSection').hidden,true);assert.equal(w.document.getElementById('recoveryEmailUnavailable').hidden,true);assert.ok(w.document.querySelector('a.account-link'));
 }finally{dom.window.close();}
});
