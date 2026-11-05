'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),{JSDOM}=require('jsdom');
test('personal library renders only visible previews in bounded frames and skips removed cards',()=>{
 const dom=new JSDOM('<main></main>',{runScripts:'outside-only'}),w=dom.window;try{
  let intersect;const observed=[],frames=[];w.IntersectionObserver=class{constructor(cb){intersect=cb;}observe(node){observed.push(node);}unobserve(){}};w.requestAnimationFrame=fn=>{frames.push(fn);return frames.length;};
  w.eval(fs.readFileSync('app/js/personal-thumbnails.js','utf8'));let rendered=0;
  for(let i=0;i<100;i++)w.document.querySelector('main').append(w.PersonalThumbnails.create({id:i},()=>{rendered++;return 'data:image/png;base64,AAAA';}));
  assert.equal(rendered,0);assert.equal(frames.length,0);observed[2].remove();intersect(observed.slice(0,4).map(target=>({target,isIntersecting:true})));assert.equal(frames.length,1);frames.shift()();assert.equal(rendered,2);assert.equal(frames.length,1);frames.shift()();assert.equal(rendered,3);assert.equal(w.document.querySelectorAll('img').length,3);assert.equal(w.document.querySelectorAll('img[alt=""]').length,3);
 }finally{w.close();}
});
