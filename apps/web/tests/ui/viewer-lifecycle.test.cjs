'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),{JSDOM}=require('jsdom');
const source=fs.readFileSync('app/js/sistema-3d-viewer.js','utf8');
function setup(){const dom=new JSDOM('<div id="viewer"></div>',{url:'https://astha.test/app/sistema.html',runScripts:'outside-only',pretendToBeVisual:true}),w=dom.window;w.eval(source+'\nwindow.AuditViewer=ASTHAViewer3D;');return{dom,w,Viewer:w.AuditViewer};}
test('model resource loading accepts embedded resources and same-origin blobs but rejects outside destinations',()=>{
 const {w}=setup();try{w.THREE={LoadingManager:class{setURLModifier(fn){this.resolveURL=fn;}}};const manager=w.createViewerResourceManager();
 for(const url of ['data:image/png;base64,AAAA','data:application/octet-stream;base64,AAAA','blob:https://astha.test/synthetic-texture'])assert.equal(manager.resolveURL(url),url);
 for(const url of ['https://outside.invalid/tracker.png','http://127.0.0.1/private','file:///secret','javascript:alert(1)','../unattached.png','blob:https://outside.invalid/synthetic','data:text/html;base64,AAAA'])assert.throws(()=>manager.resolveURL(url),/incorporados ou anexos/);
 }finally{w.close();}
});
test('late model results after closing or replacing the viewer release geometry, material arrays and textures',()=>{
 const {w,Viewer}=setup();try{for(const disposed of [true,false]){let geometry=0,material=0,texture=0,completed=0;const shared={isTexture:true,dispose(){texture++;}},mat={map:shared,dispose(){material++;}},geo={dispose(){geometry++;}};const object={traverse(fn){fn({geometry:geo,material:[mat,mat]});fn({geometry:geo,material:mat});}};
 const viewer=Object.create(Viewer.prototype);Object.assign(viewer,{disposed,loadGeneration:2});viewer._finishSetup(object,'gltf',()=>completed++,1);assert.equal(completed,0);assert.deepEqual({geometry,material,texture},{geometry:1,material:1,texture:1});}
 }finally{w.close();}
});
test('viewer disposal releases GPU objects, controls, observers and owned fetch once',()=>{
 const {w,Viewer}=setup();try{const calls={geometry:0,material:0,controls:0,observer:0,renderer:0,abort:0};const viewer=Object.create(Viewer.prototype),canvas=w.document.createElement('canvas'),container=w.document.getElementById('viewer');container.append(canvas);Object.assign(viewer,{disposed:false,reqFrame:null,loadGeneration:1,_blobUrls:[],container,loadController:{abort(){calls.abort++;}},controls:{removeEventListener(){},dispose(){calls.controls++;}},scene:{traverse(fn){fn({geometry:{dispose(){calls.geometry++;}},material:{dispose(){calls.material++;}}});},clear(){}},resizeObserver:{disconnect(){calls.observer++;}},renderer:{domElement:canvas,dispose(){calls.renderer++;}}});viewer.dispose();viewer.dispose();assert.equal(container.children.length,0);assert.deepEqual(calls,{geometry:1,material:1,controls:1,observer:1,renderer:1,abort:1});
 }finally{w.close();}
});
test('GLTF parser asynchronous errors reach the existing error UI and no unrelated images are prefetched',async()=>{
 const {w,Viewer}=setup();try{const requested=[],errors=[];class Group{add(){}remove(){}traverse(){}clear(){}}w.THREE={Group,LoadingManager:class{setURLModifier(){}},GLTFLoader:class{parse(_buffer,_base,_ok,fail){w.queueMicrotask(()=>fail(new Error('invalid synthetic GLTF')));}}};w.fetch=async url=>{requested.push(url);return{ok:true,arrayBuffer:async()=>new ArrayBuffer(8)};};Viewer.prototype.init=function(){this.scene=new Group();this.camera={};this.controls={};};const viewer=new Viewer('viewer');viewer._showError=message=>errors.push(message);let failed=0;viewer.loadModel('/synthetic.gltf','gltf',()=>assert.fail('should not succeed'),()=>failed++,{code:'SYNTHETIC',files:[{id:1,mime_type:'image/png'}]});await new Promise(resolve=>setImmediate(resolve));assert.deepEqual(requested,['/synthetic.gltf']);assert.deepEqual(errors,['invalid synthetic GLTF']);assert.equal(failed,1);
 }finally{w.close();}
});
test('model fetch never sends a session to another origin or follows a redirect and a replaced request is aborted',async()=>{
 const {w,Viewer}=setup();try{const requests=[],errors=[];class Group{add(){}remove(){}traverse(){}clear(){}}w.THREE={Group};w.localStorage.setItem('astha_token','synthetic-session');w.fetch=(url,options)=>{requests.push({url,options});return new Promise(()=>{});};Viewer.prototype.init=function(){this.scene=new Group();this.camera={};this.controls={};};const viewer=new Viewer('viewer');viewer._showError=message=>errors.push(message);
 viewer.loadModel('https://outside.invalid/model.glb','glb',null,()=>{});await new Promise(resolve=>setImmediate(resolve));assert.equal(requests.length,0);assert.match(errors[0],/não autorizada/);
 viewer.loadModel('/api/synthetic/model.glb','glb');assert.equal(requests[0].options.headers.Authorization,'Bearer synthetic-session');assert.equal(requests[0].options.redirect,'error');const first=requests[0].options.signal;
 viewer.loadModel('blob:https://astha.test/synthetic','glb');assert.equal(first.aborted,true);assert.equal(Object.keys(requests[1].options.headers).length,0);
 }finally{w.close();}
});
test('closing a fullscreen viewer before delayed initialization starts no renderer or request; latest open wins',()=>{
 const {w,Viewer}=setup();try{w.document.body.innerHTML='<div id="viewer3DModal"><div id="viewer3DTitle"></div><div id="viewer3DLoading"></div><div id="viewer3DContainer"></div></div>';const timers=new Map(),loaded=[];let next=0,created=0;w.setTimeout=fn=>{timers.set(++next,fn);return next;};w.clearTimeout=id=>timers.delete(id);Viewer.prototype.init=function(){created++;};Viewer.prototype.loadModel=function(url){loaded.push(url);};
 w.open3DViewer('/first.glb','glb','First');w.close3DViewer();assert.equal(timers.size,0);assert.equal(created,0);w.open3DViewer('/first.glb','glb','First');w.open3DViewer('/second.glb','glb','Second');assert.equal(timers.size,1);[...timers.values()][0]();assert.equal(created,1);assert.deepEqual(loaded,['/second.glb']);assert.match(w.document.getElementById('viewer3DTitle').textContent,/Second/);
 }finally{w.close();}
});
test('a second material gallery replaces its pending preview before any old model can be requested',()=>{
 const {w,Viewer}=setup();try{w.document.body.innerHTML='<div id="moreInfoModal" class="active"><div id="eoMediaGallery"><div id="eoMediaImage"></div><div id="eoMediaCanvas"></div><div id="eoMediaLoading"></div></div></div>';const timers=new Map(),loaded=[];let next=0;w.setTimeout=fn=>{timers.set(++next,fn);return next;};w.clearTimeout=id=>timers.delete(id);Viewer.prototype.init=function(){};Viewer.prototype.loadModel=function(url){loaded.push(url);};w.setupInfoMediaGallery(1,'FIRST','First','glb');w.setupInfoMediaGallery(2,'SECOND','Second','glb');assert.equal(timers.size,1);[...timers.values()][0]();assert.deepEqual(loaded,['/api/materials/SECOND/files/2/data']);
 }finally{w.close();}
});
test('session or API changes while a model response body is downloading cannot publish or parse the previous bytes',async()=>{
 for(const change of ['session','api']){const {w,Viewer}=setup();try{let finishBody,parsed=0,completed=0,failed=0;class Group{add(){}remove(){}traverse(){}clear(){}}w.THREE={Group,GLTFLoader:class{parse(){parsed++;}}};w.API={BASE_URL:'/api'};w.localStorage.setItem('astha_token','synthetic-first');w.fetch=async()=>({ok:true,arrayBuffer:()=>new Promise(resolve=>{finishBody=resolve;})});Viewer.prototype.init=function(){this.scene=new Group();this.camera={};this.controls={};};const viewer=new Viewer('viewer');viewer._showError=()=>failed++;viewer.loadModel('/api/synthetic.glb','glb',()=>completed++,()=>failed++);await new Promise(resolve=>setImmediate(resolve));assert.equal(typeof finishBody,'function');if(change==='session')w.localStorage.setItem('astha_token','synthetic-next');else w.API.BASE_URL='https://other.invalid/api';finishBody(new ArrayBuffer(8));await new Promise(resolve=>setImmediate(resolve));assert.deepEqual({parsed,completed,failed},{parsed:0,completed:0,failed:0});
 }finally{w.close();}}
});
test('parsed models from a previous session are disposed before attaching them to a viewer',()=>{
 const {w,Viewer}=setup();try{let released=0,completed=0;const object={traverse(fn){fn({geometry:{dispose(){released++;}}});}};const viewer=Object.create(Viewer.prototype);Object.assign(viewer,{disposed:false,loadGeneration:1,loadStillCurrent:()=>false});viewer._finishSetup(object,'gltf',()=>completed++,1);assert.equal(released,1);assert.equal(completed,0);
 }finally{w.close();}
});
