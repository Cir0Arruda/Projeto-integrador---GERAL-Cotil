const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{test}=require('node:test');
const root=path.resolve(__dirname,'../..');
test('browser assets and backend support CAD in the visual and assembly flows', () => {
  const html = fs.readFileSync(path.join(root, 'app/sistema.html'), 'utf8');
  const worker = fs.readFileSync(path.join(root, 'app/js/eam-cad-worker.js'), 'utf8');
  const workspace = fs.readFileSync(path.join(root, 'app/js/eam-visual-workspace.js'), 'utf8');
  const routes = fs.readFileSync(path.join(root, 'api/routes/eam.js'), 'utf8');
  assert.match(html, /eam-cad-import\.js/);
  assert.match(worker, /ReadStepFile/);
  assert.match(worker, /ReadIgesFile/);
  assert.match(workspace, /EamCadImport\.parse/);
  assert.match(routes, /glb\|step\|stp\|iges\|igs/);
  assert(fs.statSync(path.join(root, 'app/vendor/occt-import-js/occt-import-js.wasm')).size > 1000000);
});
