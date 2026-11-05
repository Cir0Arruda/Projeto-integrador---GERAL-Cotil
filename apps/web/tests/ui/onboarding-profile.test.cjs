'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('jsdom');
const html=fs.readFileSync('app/onboarding.html','utf8');
async function boot(){
 const dom=new JSDOM(html,{runScripts:'outside-only',url:'http://localhost/app/onboarding.html'}),w=dom.window,calls=[];
 w.scrollTo=()=>{};w.localStorage.setItem('astha_token','test-only');w.fetch=async(url,options={})=>{calls.push({url,options});return {ok:true,headers:{get:()=> 'application/json'},json:async()=>({name:'QA',setup_done:false})};};
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
  assert.equal(JSON.parse(calls.find(c=>c.url==='/api/org/me').options.body).workspace_type,'personal');
  w.goStep(1);w.selectWorkspaceType('corporate');assert.equal(w.document.querySelectorAll('.ob-nav-item').length,6);assert.equal(w.document.getElementById('obCorporateFields').hidden,false);assert.equal(w.document.getElementById('optJoin').hidden,false);
  await w.startProfile();await w.saveProfile();assert.equal(w.document.querySelector('.ob-step.active').id,'step3');
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
