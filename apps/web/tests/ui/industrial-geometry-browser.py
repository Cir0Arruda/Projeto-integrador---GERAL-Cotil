"""Browser verification of current procedural factories with synthetic dimensions."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

root=Path(__file__).resolve().parents[2]
out=root/'tests/.runtime/performance-audit'
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    try:
        page=browser.new_page()
        page.set_content('<!doctype html><title>ASTHA synthetic geometry checks</title>')
        page.add_script_tag(path=str(out/'three-r128.js'))
        for file in ['sistema-industrial-catalog.js','sistema-industrial-generators.js','sistema-object-library.js']:
            page.add_script_tag(path=str(root/'app/js'/file))
        page.wait_for_load_state('networkidle')
        result=page.evaluate('''()=>{
          let cases=0;const started=performance.now();
          for(const def of ASTHAIndustrialCatalog.models)for(const limit of ['min','max']){
            const parameters=Object.fromEntries(Object.entries(def.parameters).map(([k,v])=>[k,v[limit]])),object=ASTHAObjectLibrary.create(def.id,def.w,def.height,def.d,{parameters});
            const bounds=new THREE.Box3().setFromObject(object),size=bounds.getSize(new THREE.Vector3());
            if([size.x,size.y,size.z].some((v,i)=>Math.abs(v-[def.w,def.height,def.d][i])>.01)||Math.abs(bounds.min.y)>.01)throw Error(def.id+' '+limit+' dimensions');
            if(!object.isLOD||object.levels.length!==2)throw Error(def.id+' LOD');
            const geos=new Set(),materials=new Set();object.traverse(o=>{if(o.geometry)geos.add(o.geometry);for(const m of (Array.isArray(o.material)?o.material:o.material?[o.material]:[]))materials.add(m);});geos.forEach(g=>g.dispose());materials.forEach(m=>m.dispose());cases++;
          }
          return{models:ASTHAIndustrialCatalog.models.length,cases,levels:2,limits:['min','max'],allDimensionsFinite:true,elapsedMs:Math.round(performance.now()-started)};
        }''')
        (out/'industrial-geometry-r1.json').write_text(json.dumps(result,indent=2),encoding='utf8')
        print(json.dumps(result))
    finally:
        browser.close()
