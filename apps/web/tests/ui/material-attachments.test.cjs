'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),{JSDOM}=require('jsdom');
function boot(){
 const dom=new JSDOM(fs.readFileSync('app/sistema.html','utf8'),{runScripts:'outside-only',url:'http://qa.invalid/app/sistema.html'}),w=dom.window;
 w.currentWarehouseId=1;w.showToast=()=>{};w.initAppData=async()=>{};w.WarehouseUI={preparePositions:async()=>{}};
 w.eval(fs.readFileSync('app/js/security.js','utf8')+'\n'+fs.readFileSync('app/js/sistema-features.js','utf8')+'\nwindow.queuedFiles=()=>matPendingFiles;window.seedFiles=files=>{matPendingFiles=files;renderPendingFileLists();};');
 return{w,d:w.document,close:()=>w.close()};
}
const file=(name,id)=>({category:'manual',filename:name,mime_type:'application/pdf',file_data:'data:application/pdf;base64,JVBERi0xLjQ=',file_size_kb:1,_temp_id:id});
test('attachment names are inert text even before upload',()=>{
 const {w,d,close}=boot();try{const name='<img src=x onerror=alert(1)>.pdf';w.seedFiles([file(name,1)]);assert.equal(d.querySelector('#filelist-manual .eo-file-name').textContent,name);assert.equal(d.querySelectorAll('#filelist-manual img').length,0);}finally{close();}
});
test('oversized files never reach FileReader and closing a form discards a late read',async()=>{
 const {w,d,close}=boot();try{const readers=[];w.FileReader=class{readAsDataURL(){readers.push(this);}};
  await w.addFilesToQueue([{name:'large.pdf',size:10*1024*1024+1,type:'application/pdf'}],'manual');assert.equal(readers.length,0);assert.equal(d.getElementById('materialSubmitBtn').disabled,false);
  const pending=w.addFilesToQueue([{name:'old.pdf',size:20,type:'application/pdf'}],'manual');assert.equal(d.getElementById('materialSubmitBtn').disabled,true);w.closeMaterialModal();await w.openNewMaterialModal();readers[0].onload({target:{result:'data:application/pdf;base64,JVBERi0='}});await pending;assert.equal(w.queuedFiles().length,0);assert.equal(d.getElementById('materialSubmitBtn').disabled,false);
 }finally{close();}
});
test('partial upload retains the form and retries only failed files without recreating the material or clearing a legacy manual',async()=>{
 const {w,d,close}=boot();try{const calls=[];let retry=false;w.API={post:async(url,body)=>{calls.push({method:'POST',url,body});return url==='/materials'?{success:true,data:{code:'QA-1'}}:body.filename==='retry.pdf'&&!retry?{success:false,error:'Falha de teste'}:{success:true,data:{id:body.filename==='good.pdf'?1:2}};},put:async(url,body)=>{calls.push({method:'PUT',url,body});return{success:true};}};
  await w.openNewMaterialModal();d.getElementById('matDesc').value='Material de teste';w.seedFiles([file('good.pdf',1),file('retry.pdf',2)]);const event={preventDefault(){},target:d.getElementById('materialForm')};await w.handleMaterialSubmit(event);
  assert.equal(d.getElementById('materialModal').classList.contains('active'),true);assert.equal(d.getElementById('matEditCode').value,'QA-1');assert.match(d.getElementById('materialFileStatus').textContent,/1 anexo/);assert.equal(Object.hasOwn(calls[0].body,'manual_url'),false);assert.equal(Object.hasOwn(calls[0].body,'manual_data'),false);
  retry=true;await w.handleMaterialSubmit(event);assert.equal(calls.filter(c=>c.url==='/materials').length,1);assert.equal(calls.filter(c=>c.method==='PUT').length,1);assert.equal(calls.filter(c=>c.body.filename==='good.pdf').length,1);assert.equal(calls.filter(c=>c.body.filename==='retry.pdf').length,2);assert.equal(d.getElementById('materialModal').classList.contains('active'),false);
 }finally{close();}
});
test('opening a stored attachment uses authenticated fetch and a named blob download',async()=>{
 const {w,d,close}=boot();try{d.getElementById('matEditCode').value='QA-1';w.localStorage.setItem('astha_token','qa-session');w.API={BASE_URL:'/api',get:async()=>({success:true,data:[{id:7,category:'manual',filename:'manual.pdf',mime_type:'application/pdf'}]})};let fetched=0,download;
  w.fetch=async(url,options)=>{fetched++;assert.equal(url,'/api/materials/QA-1/files/7/data');assert.equal(options.headers.Authorization,'Bearer qa-session');assert.equal(options.redirect,'error');return{ok:true,blob:async()=>new w.Blob(['%PDF-1.4'])};};w.URL.createObjectURL=()=> 'blob:qa';w.URL.revokeObjectURL=()=>{};w.HTMLAnchorElement.prototype.click=function(){download={name:this.download,url:this.href};};await w.loadExistingFiles('QA-1');await w.openFileFromPending('',7,'manual');assert.equal(fetched,1);assert.deepEqual(download,{name:'manual.pdf',url:'blob:qa'});
 }finally{close();}
});
test('a late attachment listing cannot populate a different material form',async()=>{
 const {w,close}=boot();try{let respond;w.API={get:()=>new Promise(resolve=>{respond=resolve;})};const pending=w.loadExistingFiles('OLD');w.closeMaterialModal();await w.openNewMaterialModal();respond({success:true,data:[{id:1,category:'manual',filename:'old.pdf'}]});await pending;assert.equal(w.queuedFiles().length,0);}finally{close();}
});
test('external attachment references never receive the local authentication token',async()=>{
 const {w,close}=boot();try{let opened=null,fetches=0;w.localStorage.setItem('astha_token','private-session');w.open=(url,_target,features)=>{opened={url,features};};w.fetch=async()=>{fetches++;throw Error('Must not send credentials');};await w._openInfoFile(1,'QA-1','manual.pdf','https://example.invalid/manual.pdf');assert.deepEqual(opened,{url:'https://example.invalid/manual.pdf',features:'noopener'});assert.equal(fetches,0);opened=null;await w._openInfoFile(1,'QA-1','manual.pdf','javascript:alert(1)');assert.equal(opened,null);assert.equal(fetches,0);}finally{close();}
});
