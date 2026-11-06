"""Real Three r128/WebGL assembly smoke on an owned loopback-only fixture server.

Requires reviewed Khronos assets in tests/.runtime/tcc-3d-assets and the already
downloaded production-version Three/Orbit/GLTF scripts in performance-audit.
Does not connect to a database or the production VPS.
"""
import json
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tests/.runtime/tcc-3d-assets'
ENGINES = ROOT / 'tests/.runtime/performance-audit'
ASSETS = {1: 'Box', 2: 'BoxVertexColors', 3: 'Avocado'}
HTML = b'''<!doctype html><meta charset="utf-8"><style>
body{margin:0;font:16px Arial;background:#eef1f5}#target{width:1100px;margin:20px auto}
.eam-visual-3d{width:1100px;height:680px;position:relative}.eam-visual-part-tooltip{position:absolute;background:white;padding:12px;pointer-events:none}
.eam-explode-control{display:flex;gap:20px;background:white;padding:20px}input{width:700px}
</style><div id="target"></div><script>
window.API={BASE_URL:'/api'};localStorage.setItem('astha_token','synthetic-render-session');
</script><script src="/three.js"></script><script src="/orbit.js"></script><script src="/gltf.js"></script>
<script src="/viewer.js"></script><script src="/core.js"></script><script src="/workspace.js"></script>'''

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass
    def do_GET(self):
        content, mime = None, 'application/javascript'
        if self.path == '/': content, mime = HTML, 'text/html'
        elif self.path in ['/three.js', '/orbit.js', '/gltf.js']:
            filename = {'/three.js': 'three-r128.js', '/orbit.js': 'orbit-r128.js', '/gltf.js': 'gltf-r128.js'}[self.path]
            content = (ENGINES / filename).read_bytes()
        elif self.path == '/viewer.js':
            content = (ROOT / 'app/js/sistema-3d-viewer.js').read_bytes() + b'\nwindow.auditViewer=ASTHAViewer3D;'
        elif self.path == '/core.js':
            text = (ROOT / 'app/js/sistema-core.js').read_text('utf-8')
            content = re.search(r'async function fetchEamAttachment\(url,\{signal\}=\{\}\)\{[\s\S]*?\n\}', text)[0].encode()
        elif self.path == '/workspace.js':
            text = (ROOT / 'app/js/eam-visual-workspace.js').read_text('utf-8')
            content = text.replace('window.EamVisualWorkspace = {', 'window.audit3D={compositeStage,parseModel,getViewer:()=>activeViewer};window.EamVisualWorkspace = {').encode()
        elif re.fullmatch(r'/api/eam/assets/1/visuals/[123]/data', self.path):
            index = int(self.path.split('/')[-2])
            content, mime = (OUT / (ASSETS[index] + '.glb')).read_bytes(), 'model/gltf-binary'
        if content is None:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', str(len(content)))
        self.end_headers()
        self.wfile.write(content)

def main():
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            try:
                page = browser.new_page(viewport={'width': 1440, 'height': 900})
                errors = []
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.goto(f'http://127.0.0.1:{server.server_address[1]}/', wait_until='networkidle')
                loaded = page.evaluate('''async () => {
                  window.drawCalls=0;
                  const parts=[{visual_id:1,filename:'Box.glb',tx:-2,explode_dx:-2},
                    {visual_id:2,filename:'BoxVertexColors.glb',tx:0,explode_dy:2},
                    {visual_id:3,filename:'Avocado.glb',tx:2,explode_dx:2,scale_factor:20}];
                  await audit3D.compositeStage(document.getElementById('target'),1,parts,'exploded',[],()=>{},()=>{},false);
                  const viewer=audit3D.getViewer();
                  const render=viewer.renderer.render;
                  viewer.renderer.render=function(...args){drawCalls++;return render.apply(this,args)};
                  window.parts=viewer.modelGroup.children[0].children;
                  return {parts:parts.length,meshRoots:window.parts.length};
                }''')
                assert loaded['meshRoots'] == 3, loaded
                page.wait_for_timeout(1600)
                page.screenshot(path=str(OUT / 'assembly-exploded.png'), full_page=True)
                before = page.evaluate('drawCalls')
                page.wait_for_timeout(600)
                idle = page.evaluate('drawCalls') - before
                assert idle == 0, idle
                before = page.evaluate('drawCalls')
                page.get_by_role('slider', name='Distância da vista explodida').focus()
                page.keyboard.press('Home')
                page.wait_for_timeout(200)
                slider_draws = page.evaluate('drawCalls') - before
                assert slider_draws > 0, page.evaluate('({drawCalls,range:document.querySelector("input[type=range]").value,active:audit3D.getViewer().active,disposed:audit3D.getViewer().disposed,req:audit3D.getViewer().reqFrame,hidden:document.hidden})')
                assert page.get_by_role('slider').input_value() == '0'
                page.screenshot(path=str(OUT / 'assembly-normal.png'), full_page=True)
                point = page.evaluate('''() => {
                  const v=audit3D.getViewer(),p=new THREE.Box3().setFromObject(parts[1]).getCenter(new THREE.Vector3()).project(v.camera);
                  const box=v.renderer.domElement.getBoundingClientRect();return{x:box.left+(p.x+1)*box.width/2,y:box.top+(1-p.y)*box.height/2};
                }''')
                before = page.evaluate('drawCalls')
                page.mouse.move(point['x'], point['y'])
                page.wait_for_timeout(200)
                hover_draws = page.evaluate('drawCalls') - before
                assert hover_draws > 0, hover_draws
                page.screenshot(path=str(OUT / 'assembly-hover.png'), full_page=True)
                disposed = page.evaluate('''() => {
                  const v=audit3D.getViewer();window.released={geometry:0,material:0};
                  const geometries=new Set(),materials=new Set();v.scene.traverse(o=>{if(o.geometry)geometries.add(o.geometry);for(const m of(Array.isArray(o.material)?o.material:o.material?[o.material]:[]))materials.add(m)});
                  geometries.forEach(g=>g.addEventListener('dispose',()=>released.geometry++));
                  materials.forEach(m=>m.addEventListener('dispose',()=>released.material++));
                  EamVisualWorkspace.invalidate();EamVisualWorkspace.invalidate();return{...released,canvases:document.querySelectorAll('canvas').length};
                }''')
                assert disposed['geometry'] >= 3 and disposed['material'] >= 3 and disposed['canvases'] == 0, disposed
                assert not errors, errors
                report = {'status': 'TCC_REAL_3D_PASSED', **loaded, 'idleDrawCalls': idle,
                          'sliderDrawCalls': slider_draws, 'hoverDrawCalls': hover_draws,
                          'disposal': disposed, 'pageErrors': errors, 'renderer': 'Chromium software WebGL'}
                (OUT / 'render-result.json').write_text(json.dumps(report, indent=2), 'utf-8')
                print(json.dumps(report))
            finally:
                browser.close()
    finally:
        server.shutdown()
        server.server_close()
        thread.join()

if __name__ == '__main__':
    main()
