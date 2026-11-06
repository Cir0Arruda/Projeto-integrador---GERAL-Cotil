'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('jsdom');
const html=fs.readFileSync('app/onboarding.html','utf8');
async function boot(responder){
 const dom=new JSDOM(html,{runScripts:'outside-only',url:'http://localhost/app/onboarding.html'}),w=dom.window,calls=[];
 w.scrollTo=()=>{};w.localStorage.setItem('astha_token','test-only');w.fetch=async(url,options={})=>{calls.push({url,options});if(responder)return responder(url,options);return {ok:true,headers:{get:()=> 'application/json'},json:async()=>({name:'QA',setup_done:false})};};
 w.eval(fs.readFileSync('app/js/profile-avatar.js','utf8')+'\n'+fs.readFileSync('app/js/onboarding-profile.js','utf8')+'\n'+[...w.document.scripts].find(s=>s.textContent.includes('let currentStep')).textContent);
 await new Promise(r=>setImmediate(r));return {dom,w,calls};
}
test('type selection precedes profile and personal flow omits corporate steps',async()=>{
 const {dom,w,calls}=await boot();try{
  await w.startProfile();assert.equal(w.document.querySelector('.ob-step.active').id,'step1');
  w.selectWorkspaceType('personal');await w.startProfile();assert.equal(w.document.querySelector('.ob-step.active').id,'step2');
  assert.equal(w.document.activeElement,w.document.querySelector('#step2 .ob-title'));
  assert.equal(w.document.querySelector('#nav3'),null);assert.equal(w.document.querySelector('#nav5'),null);
  assert.deepEqual([...w.document.querySelectorAll('.ob-nav-dot-num')].map(e=>e.textContent),['1','2','3','4']);
  assert.equal(w.document.querySelector('#obPositionLabel').closest('.ob-field').hidden,true);
  w.document.getElementById('obName').value='QA';await w.saveProfile();assert.equal(w.document.querySelector('.ob-step.active').id,'step4');
  const body=JSON.parse(calls.find(c=>c.url==='/api/auth/profile').options.body);assert.ok(!('position_label' in body));assert.ok(!('avatar_url' in body));
  w.document.getElementById('obOrgName').value='Meu espaço';await w.saveOrgData();assert.equal(w.document.querySelector('.ob-step.active').id,'step6');
  assert.equal(w.document.querySelector('#sumPositions').closest('.ob-summary-row').hidden,true);
  assert.equal(JSON.parse(calls.find(c=>c.url==='/api/org/me'&&c.options.method==='PUT').options.body).workspace_type,'personal');
  w.goStep(1);w.selectWorkspaceType('corporate');assert.equal(w.document.querySelectorAll('.ob-nav-item').length,6);assert.equal(w.document.getElementById('obCorporateFields').hidden,false);assert.equal(w.document.getElementById('optJoin').hidden,false);
  await w.startProfile();await w.saveProfile();assert.equal(w.document.querySelector('.ob-step.active').id,'step3');
 }finally{dom.window.close();}
});

const reply=(data,ok=true)=>({ok,headers:{get:()=> 'application/json'},json:async()=>data});
test('late startup data preserves edited and deliberately cleared fields',async()=>{
 let releaseMe,releaseOrg;
 const {dom,w}=await boot(url=>{
  if(url==='/api/auth/me')return new Promise(resolve=>{releaseMe=()=>resolve(reply({id:1,org_id:'c',setup_done:false,name:'Nome anterior',surname:'Antigo',phone:'123',org_name:'Empresa anterior'}));});
  if(url==='/api/org/me')return new Promise(resolve=>{releaseOrg=()=>resolve(reply({name:'Empresa salva',city:'Limeira',email:'old@example.invalid'}));});
  return reply([]);
 });
 try{
  for(const [id,value] of [['obName','Nome editado'],['obSurname',''],['obOrgName','Empresa editada'],['obOrgEmail','']]){
   const input=w.document.getElementById(id);input.value=value;input.dispatchEvent(new w.Event('input',{bubbles:true}));
  }
  releaseMe();await new Promise(resolve=>setImmediate(resolve));
  assert.equal(w.document.getElementById('obName').value,'Nome editado');
  assert.equal(w.document.getElementById('obSurname').value,'');
  assert.equal(w.document.getElementById('obPhone').value,'123');
  releaseOrg();await new Promise(resolve=>setImmediate(resolve));
  assert.equal(w.document.getElementById('obOrgName').value,'Empresa editada');
  assert.equal(w.document.getElementById('obOrgEmail').value,'');
  assert.equal(w.document.getElementById('obCity').value,'Limeira');
 }finally{dom.window.close();}
});
test('temporary validation failure keeps the signed-in account for retry',async()=>{
 const {dom,w}=await boot(()=>({...reply({error:'Indisponível'},false),status:503}));
 try{assert.equal(w.localStorage.getItem('astha_token'),'test-only');}
 finally{dom.window.close();}
});
test('personal resume skips the corporate positions route',async()=>{
 const {dom,w,calls}=await boot(url=>url==='/api/auth/me'?reply({id:1,org_id:'p',name:'QA',workspace_type:'personal',setup_done:false}):reply({name:'Meu espaço'}));
 try{assert.ok(!calls.some(call=>call.url==='/api/org/positions'));assert.equal(w.document.querySelector('#obAlertMsg').textContent,'');}
 finally{dom.window.close();}
});
test('late initial positions do not erase a position committed during startup',async()=>{
 let release;
 const {dom,w}=await boot((url,options)=>{
  if(url==='/api/org/positions'&&options.method==='POST')return reply({id:77});
  if(url==='/api/org/positions')return new Promise(resolve=>{release=()=>resolve(reply([]));});
  return reply({id:1,org_id:'c',name:'QA',workspace_type:'corporate',setup_done:false});
 });
 try{
  w.selectWorkspaceType('corporate');w.goStep(5);w.document.getElementById('posName').value='Técnico';w.addPosition();await w.savePositions();
  assert.equal(w.document.querySelectorAll('#posList .ob-pos-card').length,1);
  release();await new Promise(resolve=>setImmediate(resolve));
  assert.equal(w.document.querySelectorAll('#posList .ob-pos-card').length,1);
 }finally{dom.window.close();}
});
test('lost commit response plus late initial read collapses by ID after replay',async()=>{
 let release,lost=true,key;
 const {dom,w}=await boot((url,options)=>{
  if(url==='/api/org/positions'&&options.method==='POST'){
   const body=JSON.parse(options.body);if(key)assert.equal(body.request_key,key);else key=body.request_key;
   if(lost){lost=false;throw Error('Response lost after commit');}return reply({id:7});
  }
  if(url==='/api/org/positions')return new Promise(resolve=>{release=()=>resolve(reply([{id:7,name:'Técnico',department:'',level:3,color:'#6366f1'}]));});
  return reply({id:1,org_id:'c',name:'QA',workspace_type:'corporate',setup_done:false});
 });
 try{
  w.selectWorkspaceType('corporate');w.goStep(5);w.document.getElementById('posName').value='Técnico';w.addPosition();await w.savePositions();
  release();await new Promise(resolve=>setImmediate(resolve));
  await w.savePositions();
  assert.equal(w.document.querySelectorAll('#posList .ob-pos-card').length,1);
  assert.equal(w.document.getElementById('sumPositions').textContent,'1 cargo(s)');
 }finally{dom.window.close();}
});
test('resuming onboarding restores company details and already persisted positions',async()=>{
 const {dom,w,calls}=await boot((url,options)=>{
  if(url==='/api/org/me')return reply({name:'Empresa de teste',cnpj:'123',email:'qa@example.invalid',phone:'12345678',city:'Limeira',state:'SP'});
  if(url==='/api/org/positions')return reply([{id:7,name:'Técnico',department:'Manutenção',level:3,color:'#123456'}]);
  return reply({id:1,org_id:'test',name:'QA',setup_done:false,workspace_type:'corporate'});
 });
 try{
  assert.equal(w.document.getElementById('obCity').value,'Limeira');
  assert.equal(w.document.getElementById('obOrgEmail').value,'qa@example.invalid');
  assert.match(w.document.getElementById('posList').textContent,/Técnico/);
  w.goStep(5);await w.savePositions();
  assert.equal(calls.filter(c=>c.url==='/api/org/positions'&&c.options.method==='POST').length,0);
  await w.removePosition(7);
  assert.ok(calls.some(c=>c.url==='/api/org/positions/7'&&c.options.method==='DELETE'));
 }finally{dom.window.close();}
});
test('a failed position stays on its step and retry does not duplicate committed positions',async()=>{
 let failing=true;const writes=[];
 const {dom,w}=await boot((url,options)=>{
  if(url==='/api/org/positions'&&options.method==='POST'){
   const value=JSON.parse(options.body);writes.push(value.name);
   return reply(value.name==='Segundo'&&failing?{error:'Falha simulada'}:{id:value.name==='Primeiro'?1:2},!(value.name==='Segundo'&&failing));
  }
  if(url==='/api/org/positions')return reply([]);
  if(url==='/api/org/invites')return reply({code:'TESTE123'});
  return reply({name:'QA',setup_done:false});
 });
 try{
  w.selectWorkspaceType('corporate');w.goStep(5);
  for(const name of ['Primeiro','Segundo']){w.document.getElementById('posName').value=name;w.addPosition();}
  await Promise.all([w.savePositions(),w.savePositions()]);
  assert.equal(w.document.querySelector('.ob-step.active').id,'step5');
  assert.deepEqual(writes,['Primeiro','Segundo']);
  failing=false;await w.savePositions();
  assert.deepEqual(writes,['Primeiro','Segundo','Segundo']);
  assert.equal(w.document.querySelector('.ob-step.active').id,'step6');
 }finally{dom.window.close();}
});
test('photo prepares a real image, saves only after Continue and can be removed',async()=>{
 const {dom,w,calls}=await boot();try{
  w.selectWorkspaceType('corporate');await w.startProfile();const input=w.document.getElementById('obProfilePhoto');
  w.createImageBitmap=async()=>({width:300,height:400,close(){}});
  w.HTMLCanvasElement.prototype.getContext=()=>({drawImage(){}});const photo='data:image/webp;base64,UklGRg==';w.HTMLCanvasElement.prototype.toDataURL=()=>photo;
  Object.defineProperty(input,'files',{configurable:true,value:[new w.File(['fixture'],'avatar.png',{type:'image/png'})]});
  await w.readProfilePhoto(input);assert.equal(w.document.querySelector('#obPhotoPreview img').src,photo);assert.equal(calls.filter(c=>c.url==='/api/auth/profile').length,0);
  await w.saveProfile();assert.equal(JSON.parse(calls.find(c=>c.url==='/api/auth/profile').options.body).avatar_url,photo);
  assert.equal(JSON.parse(w.localStorage.getItem('astha_user')).avatar_url,photo);
  w.removeProfilePhoto();assert.equal(w.document.querySelector('#obPhotoPreview img'),null);w.goStep(2);await w.saveProfile();assert.equal(JSON.parse(calls.filter(c=>c.options.method==='PUT').at(-1).options.body).avatar_url,null);
 }finally{dom.window.close();}
});
test('invalid files and stale decoders cannot replace a removed photo',async()=>{
 const {dom,w}=await boot();try{
  const input=w.document.getElementById('obProfilePhoto');Object.defineProperty(input,'files',{configurable:true,value:[new w.File(['<svg/>'],'x.svg',{type:'image/svg+xml'})]});await w.readProfilePhoto(input);assert.equal(w.document.querySelector('#obPhotoPreview img'),null);
  let release;w.createImageBitmap=()=>new Promise(r=>{release=r;});w.HTMLCanvasElement.prototype.getContext=()=>({drawImage(){}});w.HTMLCanvasElement.prototype.toDataURL=()=> 'data:image/webp;base64,UklGRg==';
  Object.defineProperty(input,'files',{configurable:true,value:[new w.File(['fixture'],'x.png',{type:'image/png'})]});const pending=w.readProfilePhoto(input);w.removeProfilePhoto();release({width:256,height:256,close(){}});await pending;assert.deepEqual(JSON.parse(JSON.stringify(w.profilePhotoChanges())),{avatar_url:null});assert.equal(w.profilePhotoLoading(),false);
 }finally{dom.window.close();}
});
