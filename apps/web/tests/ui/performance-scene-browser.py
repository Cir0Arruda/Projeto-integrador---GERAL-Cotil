"""Local-only lifecycle measurements using the production Three.js scene classes.

Requires Playwright in the caller's Python environment. Uses synthetic furniture;
no API, authentication, application database or user records are involved.
"""
import argparse
import json
from pathlib import Path
import urllib.request

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tests" / ".runtime" / "performance-audit"
OUT.mkdir(parents=True, exist_ok=True)
parser = argparse.ArgumentParser()
parser.add_argument("--label", default="current")
parser.add_argument("--verify", action="store_true")
args = parser.parse_args()

assets = {
    "three-r128.js": "https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js",
    "orbit-r128.js": "https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js",
    "gltf-r128.js": "https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js",
}
for name, url in assets.items():
    target = OUT / name
    if not target.exists():
        with urllib.request.urlopen(url, timeout=30) as response:
            target.write_bytes(response.read())

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, args=["--enable-unsafe-swiftshader"])
    try:
        page = browser.new_page(viewport={"width": 1100, "height": 700})
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.set_content('''<!doctype html><meta charset="utf-8"><title>ASTHA synthetic scene audit</title>
        <style>body{font:16px system-ui;background:#f4f5f6;color:#14201a}main{display:flex;gap:16px}.scene{width:510px;height:500px;background:#fff}canvas{width:100%;height:100%}</style>
        <h1>ASTHA · cenas sintéticas de validação</h1><main><section><h2>Espaço pessoal</h2><div id="personal" class="scene"></div></section><section><h2>Visualizador de material</h2><div id="viewer" class="scene"></div></section></main>''')
        for name in assets:
            page.add_script_tag(path=str(OUT / name))
        page.add_script_tag(path=str(ROOT / "app/js/personal-3d.js"))
        page.add_script_tag(path=str(ROOT / "app/js/sistema-3d-viewer.js"))
        page.wait_for_load_state("networkidle")
        page.evaluate('''() => {
          window.rafCalls=0;const raf=window.requestAnimationFrame.bind(window);window.requestAnimationFrame=callback=>raf(time=>{rafCalls++;callback(time);});
          window.pScene=new Personal3D.PersonalScene(document.getElementById('personal'),{onSelect(){},onMove(){}});
          pScene.setSpace({width:6,depth:5,objects:[{id:'synthetic-cabinet',modelId:'wardrobe',color:'#c4ae91',width:1.4,height:2,depth:.6,x:2,z:1,yaw:0}]},true);
          window.vScene=new ASTHAViewer3D('viewer');
          const model=new THREE.Mesh(new THREE.BoxGeometry(50,70,50),new THREE.MeshStandardMaterial({color:'#b6c9bf'}));
          vScene.modelGroup=new THREE.Group();vScene.scene.add(vScene.modelGroup);vScene._finishSetup(model,'gltf');
          window.counts={personal:0,viewer:0};
          for(const [key,scene] of [['personal',pScene],['viewer',vScene]]){const render=scene.renderer.render.bind(scene.renderer);scene.renderer.render=(...a)=>{counts[key]++;return render(...a);};}
        }''')
        page.wait_for_timeout(2000)
        before_orbit = page.evaluate("({personal:pScene.camera.position.toArray(),viewer:vScene.camera.position.toArray()})")
        for x in [220, 760]:
            page.mouse.move(x, 350)
            page.mouse.down()
            page.mouse.move(x + 70, 375, steps=6)
            page.mouse.up()
        page.wait_for_timeout(1500)
        orbit = page.evaluate("before=>({personal:pScene.camera.position.distanceTo(new THREE.Vector3(...before.personal))>0.01,viewer:vScene.camera.position.distanceTo(new THREE.Vector3(...before.viewer))>0.01})", before_orbit)
        if args.verify:
            page.wait_for_function('pScene.frame === null && vScene.reqFrame === null', timeout=20000)
        page.evaluate("counts.personal=counts.viewer=0;rafCalls=0")
        page.wait_for_timeout(1000)
        idle = page.evaluate("({...counts})")
        idle_raf = page.evaluate("rafCalls")
        page.evaluate("document.getElementById('personal').style.display='none';document.getElementById('viewer').style.display='none';counts.personal=counts.viewer=0;rafCalls=0")
        page.wait_for_timeout(1000)
        hidden = page.evaluate("({...counts})")
        hidden_raf = page.evaluate("rafCalls")
        page.evaluate("document.getElementById('personal').style.display='block';document.getElementById('viewer').style.display='block';pScene.resize();vScene.resize();")
        page.wait_for_timeout(1000)
        page.screenshot(path=str(OUT / (args.label + ".png")), full_page=True)
        resources = page.evaluate('''async () => {
          const bytes=new Uint8Array(new Float32Array([0,0,0,1,0,0,0,1,0]).buffer),encoded=btoa(String.fromCharCode(...bytes));
          const scene={asset:{version:'2.0'},scenes:[{nodes:[0]}],scene:0,nodes:[{mesh:0}],meshes:[{primitives:[{attributes:{POSITION:0}}]}],buffers:[{uri:'data:application/octet-stream;base64,'+encoded,byteLength:36}],bufferViews:[{buffer:0,byteOffset:0,byteLength:36}],accessors:[{bufferView:0,componentType:5126,count:3,type:'VEC3',min:[0,0,0],max:[1,1,0]}]};
          const parse=data=>new Promise((resolve,reject)=>new THREE.GLTFLoader(createViewerResourceManager()).parse(JSON.stringify(data),'',resolve,reject));
          const embedded=await parse(scene);disposeViewerResources(embedded.scene);
          scene.buffers[0].uri='https://outside.invalid/private-buffer';let rejected=false;
          try{await parse(scene);}catch(error){rejected=error.message.includes('incorporados ou anexos');}
          return{embeddedModelLoaded:true,externalBufferRejected:rejected};
        }''')
        page.evaluate("window.dispatchEvent(new PageTransitionEvent('pagehide',{persisted:true}));window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true}));pScene.camera.position.x+=1;pScene.controls.update();counts.personal=counts.viewer=0")
        page.wait_for_timeout(500)
        restored = page.evaluate("({...counts})")
        dispose = page.evaluate('''() => {
          let geometries=0,materials=0,controls=0;
          vScene.scene.traverse(o=>{if(o.geometry)o.geometry.addEventListener('dispose',()=>geometries++);for(const m of (Array.isArray(o.material)?o.material:[o.material]))if(m)m.addEventListener('dispose',()=>materials++);});
          const original=vScene.controls.dispose.bind(vScene.controls);vScene.controls.dispose=()=>{controls++;original();};vScene.dispose();
          if(pScene.dispose)pScene.dispose();
          return {geometries,materials,controls};
        }''')
        result = {"idleFramesPerSecond": idle, "hiddenFramesPerSecond": hidden,
                  "idleRafCallbacksPerSecond": idle_raf, "hiddenRafCallbacksPerSecond": hidden_raf,
                  "restoredFrames": restored, "viewerDisposal": dispose, "errors": errors,
                  "resourcePolicy": resources,
                  "pointerOrbitResponds": orbit,
                  "browser": browser.version, "syntheticDataOnly": True}
        (OUT / (args.label + ".json")).write_text(json.dumps(result, indent=2), encoding="utf-8")
        print(json.dumps(result))
        if args.verify:
            assert not errors, errors
            assert max(idle.values()) <= 2, idle
            assert max(hidden.values()) == 0, hidden
            assert hidden_raf <= 2, hidden_raf
            assert restored["personal"] > 0, restored
            assert resources["embeddedModelLoaded"] and resources["externalBufferRejected"], resources
            assert all(orbit.values()), orbit
            assert dispose["geometries"] >= 3 and dispose["materials"] >= 3 and dispose["controls"] == 1, dispose
    finally:
        browser.close()
