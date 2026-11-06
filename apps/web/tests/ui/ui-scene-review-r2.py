"""Independent BFCache/lifecycle review of the production personal scene, synthetic only."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tests' / '.runtime' / 'ui-scene-r2'
OUT.mkdir(parents=True, exist_ok=True)
ASSETS = ROOT / 'tests' / '.runtime' / 'performance-audit'
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, args=['--enable-unsafe-swiftshader'])
    page = browser.new_page(viewport={'width':900,'height':650})
    errors = []
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.set_content('<!doctype html><title>R2 lifecycle review</title><h1>Personal scene lifecycle review</h1><div id="scene" style="width:800px;height:500px"></div>')
    for asset in ['three-r128.js','orbit-r128.js']:
        page.add_script_tag(path=str(ASSETS/asset))
    page.add_script_tag(path=str(ROOT/'app/js/personal-3d.js'))
    page.evaluate('''() => {
      window.scene=new Personal3D.PersonalScene(document.getElementById('scene'),{onSelect(){},onMove(){}});
      scene.setSpace({width:6,depth:5,objects:[{id:'cabinet',modelId:'wardrobe',color:'#c4ae91',width:1.4,height:2,depth:.6,x:2,z:1,yaw:0}]},true);
      window.renderCount=0;const render=scene.renderer.render.bind(scene.renderer);scene.renderer.render=(...args)=>{renderCount++;return render(...args);};
      window.thumbA=Personal3D.thumbnail({id:'wardrobe',width:1.4,height:2,depth:.6,color:'#c4ae91'});
    }''')
    page.wait_for_timeout(1200)
    page.evaluate('renderCount=0;dispatchEvent(new PageTransitionEvent("pagehide",{persisted:true}))')
    page.wait_for_timeout(200)
    paused = page.evaluate('({renderCount,disposed:scene.disposed,frame:scene.frame})')
    assert not paused['disposed'] and paused['frame'] is None and paused['renderCount'] == 0, paused
    thumbnails = page.evaluate('''() => {
      const second=Personal3D.thumbnail({id:'desk',width:1.4,height:.8,depth:.7,color:'#bca78f'});
      dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true}));
      return {first:thumbA?.startsWith('data:image/png;base64,'),second:second?.startsWith('data:image/png;base64,')};
    }''')
    assert thumbnails['first'] and thumbnails['second'], thumbnails
    page.wait_for_timeout(350)
    resumed = page.evaluate('({renderCount,disposed:scene.disposed})')
    assert not resumed['disposed'] and resumed['renderCount'] > 0, resumed
    page.screenshot(path=str(OUT/'resumed.png'))
    disposed = page.evaluate('''() => {
      dispatchEvent(new PageTransitionEvent('pagehide',{persisted:false}));
      scene.dispose();return {disposed:scene.disposed,canvases:document.querySelectorAll('#scene canvas').length,frame:scene.frame};
    }''')
    assert disposed['disposed'] and disposed['canvases'] == 0 and disposed['frame'] is None, disposed
    assert not errors, errors
    result = {'paused':paused,'thumbnails':thumbnails,'resumed':resumed,'disposed':disposed,'errors':errors}
    (OUT/'results.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result))
    browser.close()
