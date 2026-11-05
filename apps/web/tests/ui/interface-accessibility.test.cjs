'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{JSDOM}=require('jsdom');
const root=path.resolve(__dirname,'../..');
test('all current HTML controls have accessible labels, close buttons have names and IDs are unique',()=>{
 for(const name of fs.readdirSync(path.join(root,'app')).filter(n=>n.endsWith('.html'))){const dom=new JSDOM(fs.readFileSync(path.join(root,'app',name),'utf8')),d=dom.window.document;try{
  const ids=new Set();for(const node of d.querySelectorAll('[id]')){assert.ok(!ids.has(node.id),name+': duplicate '+node.id);ids.add(node.id);}
  for(const node of d.querySelectorAll('input,select,textarea')){if(['hidden','submit','button','reset'].includes(node.type))continue;assert.ok(node.labels.length||node.getAttribute('aria-label')||node.getAttribute('aria-labelledby'),name+': unnamed '+node.id);}
  for(const node of d.querySelectorAll('button'))assert.ok(node.textContent.trim()||node.getAttribute('aria-label')||node.getAttribute('aria-labelledby')||node.title,name+': unnamed button');
  for(const dialog of d.querySelectorAll('dialog')){
    const label=dialog.getAttribute('aria-label')||String(dialog.getAttribute('aria-labelledby')||'').split(/\s+/).map(id=>d.getElementById(id)?.textContent||'').join(' ');
    assert.ok(label.trim(),name+': unnamed dialog '+dialog.id);
  }
  for(const node of d.querySelectorAll('[onclick]')){if(node.matches('button,a,input,select,textarea,option,label')||node.closest('button,a,label'))continue;assert.equal(node.getAttribute('role'),'button',name+': non-semantic click target');assert.equal(node.getAttribute('tabindex'),'0',name+': unreachable click target');}
 }finally{dom.window.close();}}
});

test('non-native actions respond to Enter and Space without double activation or stealing typing',()=>{
 const dom=new JSDOM('<div role="button" tabindex="0" id="action">Abrir<input aria-label="Texto"></div>',{runScripts:'outside-only'}),w=dom.window;
 try{const action=w.document.getElementById('action');let clicks=0;action.onclick=()=>{clicks++;};w.eval(fs.readFileSync(path.join(root,'app/js/keyboard-actions.js'),'utf8'));
  for(const key of ['Enter',' '])action.dispatchEvent(new w.KeyboardEvent('keydown',{key,bubbles:true,cancelable:true}));assert.equal(clicks,2);
  action.querySelector('input').dispatchEvent(new w.KeyboardEvent('keydown',{key:' ',bubbles:true,cancelable:true}));assert.equal(clicks,2);
  const handled=new w.KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true});handled.preventDefault();action.dispatchEvent(handled);action.setAttribute('aria-disabled','true');action.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));assert.equal(clicks,2);
 }finally{w.close();}
});
test('custom dialogs receive a name, contain keyboard focus and return focus when closed',async()=>{
 const dom=new JSDOM('<button id="launch">Abrir</button><div class="eo-modal-overlay" id="modal"><h2>Cadastro de teste</h2><button class="eo-modal-close">Fechar</button><input aria-label="Nome"><button id="save">Salvar</button></div>',{runScripts:'outside-only'}),w=dom.window,d=w.document;
 try{w.HTMLElement.prototype.getClientRects=function(){return [{width:10,height:10}];};w.eval(fs.readFileSync(path.join(root,'app/js/dialog-accessibility.js'),'utf8'));await new Promise(r=>setImmediate(r));const modal=d.getElementById('modal'),launch=d.getElementById('launch'),close=modal.querySelector('button');close.onclick=()=>modal.classList.remove('active');launch.focus();modal.classList.add('active');await new Promise(r=>setImmediate(r));
 assert.equal(modal.getAttribute('role'),'dialog');assert.equal(modal.getAttribute('aria-modal'),'true');assert.equal(d.getElementById(modal.getAttribute('aria-labelledby')).textContent,'Cadastro de teste');assert.equal(d.activeElement,close);
 close.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Tab',shiftKey:true,bubbles:true,cancelable:true}));assert.equal(d.activeElement.id,'save');d.activeElement.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Tab',bubbles:true,cancelable:true}));assert.equal(d.activeElement,close);
 close.disabled=true;modal.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));assert.equal(modal.classList.contains('active'),true);close.disabled=false;modal.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));await new Promise(r=>setImmediate(r));assert.equal(modal.classList.contains('active'),false);assert.equal(d.activeElement,launch);
 modal.style.display='flex';await new Promise(r=>setImmediate(r));assert.equal(d.activeElement,close);modal.style.display='none';await new Promise(r=>setImmediate(r));assert.equal(d.activeElement,launch);
 }finally{w.close();}
});
