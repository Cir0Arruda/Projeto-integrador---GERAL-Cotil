'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {JSDOM} = require('jsdom');
const workspace = fs.readFileSync('app/js/eam-visual-workspace.js', 'utf8');
const viewer = fs.readFileSync('app/js/sistema-3d-viewer.js', 'utf8');
const core = fs.readFileSync('app/js/sistema-core.js', 'utf8');
const tick = () => new Promise(resolve => setImmediate(resolve));
function setup() {
  const dom = new JSDOM('<div id="target"></div>', {url: 'https://astha.test/app/sistema.html', runScripts: 'outside-only'});
  const w = dom.window;
  w.API = {BASE_URL: '/api'};
  w.localStorage.setItem('astha_token', 'synthetic-first');
  w.eval(viewer.slice(0, viewer.indexOf('class ASTHAViewer3D')));
  w.eval(workspace.replace('window.EamVisualWorkspace = {', 'window.auditAssembly = {compositeStage, parseModel, contrastModel}; window.EamVisualWorkspace = {'));
  return {w, close: () => w.close()};
}

test('EAM attachments bind the response body to the current session and refuse outside credentials/redirects', async () => {
  const {w, close} = setup();
  try {
    w.eval(core.match(/async function fetchEamAttachment\(url,\{signal\}=\{\}\)\{[\s\S]*?\n\}/)[0]);
    const requests = [];
    w.fetch = async (url, options) => { requests.push({url, options}); return {ok: true, blob: async () => ({valid: true})}; };
    assert.equal((await w.fetchEamAttachment('/api/eam/files/1')).valid, true);
    assert.equal(requests[0].options.redirect, 'error');
    assert.equal(requests[0].options.headers.Authorization, 'Bearer synthetic-first');
    const controller = new w.AbortController();
    await w.fetchEamAttachment('/api/eam/files/2', {signal: controller.signal});
    assert.equal(requests[1].options.signal, controller.signal);
    for (const url of ['https://outside.invalid/private', 'https://user:password@astha.test/api/file', '/app/file', 'file:///private', 'javascript:alert(1)'])
      await assert.rejects(w.fetchEamAttachment(url), /não autorizada/);
    assert.equal(requests.length, 2);
    let bodyCalls = 0;
    w.fetch = async () => { w.localStorage.setItem('astha_token', 'synthetic-next'); return {ok: true, blob: async () => { bodyCalls++; }}; };
    await assert.rejects(w.fetchEamAttachment('/api/eam/files/1'), /sessão mudou/);
    assert.equal(bodyCalls, 0);
    let finishBody;
    w.fetch = async () => ({ok: true, blob: () => new Promise(resolve => { finishBody = resolve; })});
    const pending = w.fetchEamAttachment('/api/eam/files/1');
    await tick();
    w.API.BASE_URL = '/other-api';
    finishBody({private: true});
    await assert.rejects(pending, /sessão mudou/);
  } finally { close(); }
});

test('composite GLTF uses the same embedded-resource policy as the standalone viewer', async () => {
  const {w, close} = setup();
  try {
    let destination = 'data:application/octet-stream;base64,AAAA';
    w.THREE = {
      LoadingManager: class {setURLModifier(fn) { this.resolveURL = fn; }},
      GLTFLoader: class {
        constructor(manager) { this.manager = manager; }
        parse(_bytes, _path, success, failure) {
          try { this.manager.resolveURL(destination); success({scene: {valid: true}}); } catch (error) { failure(error); }
        }
      }
    };
    assert.equal((await w.auditAssembly.parseModel(new ArrayBuffer(8), 'glb')).valid, true);
    for (const url of ['https://outside.invalid/tracker.png', '../unattached.bin', 'file:///private']) {
      destination = url;
      await assert.rejects(w.auditAssembly.parseModel(new ArrayBuffer(8), 'glb'), /incorporados ou anexos/);
    }
  } finally { close(); }
});

test('a late composite download never parses a previous session and a late decoded mesh is disposed', async () => {
  for (const stage of ['body', 'decode', 'close']) {
    const {w, close} = setup();
    try {
      let parsed = 0, released = 0, aborted = 0, finishBody;
      class Group {
        constructor() { this.children = []; }
        add(child) { this.children.push(child); }
        traverse(fn) { fn(this); this.children.forEach(child => child.traverse(fn)); }
      }
      w.THREE = {
        Group,
        STLLoader: class {parse() { parsed++; w.localStorage.setItem('astha_token', 'synthetic-next'); return {dispose() { released++; }}; }},
        MeshStandardMaterial: class {dispose() {}},
        Mesh: class {constructor(geometry, material) { this.geometry = geometry; this.material = material; } traverse(fn) { fn(this); }}
      };
      w.ASTHAViewer3D = class {
        constructor() { this.scene = new Group(); this.disposed = false; }
        dispose() { if (!this.disposed) { this.disposed = true; w.disposeViewerResources(this.scene); } }
      };
      w.fetchEamAttachment = async (_url, {signal}) => {
        if (stage === 'close') return new Promise((_resolve, reject) => signal.addEventListener('abort', () => { aborted++; reject(Error('aborted')); }));
        return {arrayBuffer: () => stage === 'body' ? new Promise(resolve => { finishBody = resolve; }) : Promise.resolve(new ArrayBuffer(8))};
      };
      const pending = w.auditAssembly.compositeStage(w.document.getElementById('target'), 1, [{filename: 'part.stl', visual_id: 1}], 'assembled', []);
      await tick();
      if (stage === 'body') { w.localStorage.setItem('astha_token', 'synthetic-next'); finishBody(new ArrayBuffer(8)); }
      if (stage === 'close') w.EamVisualWorkspace.invalidate();
      await pending;
      assert.equal(parsed, stage === 'decode' ? 1 : 0);
      assert.equal(released, stage === 'decode' ? 1 : 0);
      assert.equal(aborted, stage === 'close' ? 1 : 0);
      assert.equal(w.document.querySelectorAll('.eam-explode-control').length, 0);
    } finally { close(); }
  }
});

test('assembly contrast reuses one replacement and releases the original shared material', () => {
  const {w, close} = setup();
  try {
    let cloned = 0, disposed = 0;
    const original = {color: {r: .8, g: .8, b: .8}, dispose() { disposed++; }, clone() { cloned++; return {color: {setHex() {}}, metalness: 1, roughness: 1}; }};
    const nodes = [{isMesh: true, material: original}, {isMesh: true, material: [original, original]}];
    w.auditAssembly.contrastModel({traverse(fn) { nodes.forEach(fn); }}, 0);
    assert.equal(cloned, 1);
    assert.equal(disposed, 1);
    assert.equal(nodes[0].material, nodes[1].material[0]);
    assert.equal(nodes[1].material[0], nodes[1].material[1]);
  } finally { close(); }
});
