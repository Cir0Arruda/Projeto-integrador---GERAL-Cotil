const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('jsdom');
test('maximizing and restoring 3D preserves flex sizing and requests a renderer resize',()=>{
 const dom=new JSDOM('<button id="btn-maximize-3d"></button><div id="cadWorkspace"><div><canvas id="cadCanvas2d"></canvas></div><div class="eo-cad-3d"></div></div>');
 let resized=0,events=0;const w=dom.window;
 w.resizeCad3D=()=>resized++;w.addEventListener('resize',()=>events++);
 const source=fs.readFileSync('app/js/sistema-builder-3d.js','utf8');
 const ctx={window:w,document:w.document,Event:w.Event,requestAnimationFrame:fn=>fn()};vm.createContext(ctx);
 vm.runInContext(source.slice(source.indexOf('window.toggleMaximize3D ='),source.indexOf('window.setCameraView =')),ctx);
 try{for(let n=0;n<6;n++){w.toggleMaximize3D();assert.equal(w.document.getElementById('cadWorkspace').classList.contains('cad-3d-maximized'),n%2===0);assert.equal(w.document.querySelector('.eo-cad-3d').style.position,'');assert.equal(w.document.querySelector('.eo-cad-3d').style.width,'');assert.equal(w.document.getElementById('btn-maximize-3d').getAttribute('aria-pressed'),String(n%2===0));}assert.equal(resized,6);assert.equal(events,6);}finally{w.close();}
});
