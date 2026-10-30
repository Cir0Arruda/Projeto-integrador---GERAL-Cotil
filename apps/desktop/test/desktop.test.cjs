'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { startDesktop } = require('../src/main/runtime');
function harness({ local = false, packaged = false, lock = true, response = 0 } = {}) {
  const app = new EventEmitter(), windows = [], messages = [], opened = [], handlers = new Map();
  let forks = 0, quits = 0;
  app.requestSingleInstanceLock = () => lock; app.enableSandbox = () => { app.sandboxed = true; };
  app.getPath = () => require('node:os').tmpdir(); app.isPackaged = packaged;
  app.quit = () => { quits++; app.emit('before-quit'); };
  class BrowserWindow extends EventEmitter {
    constructor(options) {
      super(); this.options = options; this.loads = [];
      this.webContents = new EventEmitter(); this.webContents.mainFrame = { url: '' };
      this.webContents.session = {
        setPermissionRequestHandler: fn => { this.permission = fn; },
        setPermissionCheckHandler: fn => { this.permissionCheck = fn; }
      };
      this.webContents.setWindowOpenHandler = fn => { this.open = fn; }; windows.push(this);
    }
    isDestroyed() { return false; } isMinimized() { return false; } restore() {} focus() { this.focused = true; }
    setMenuBarVisibility() {}
    loadURL(url) { this.loads.push(url); this.webContents.mainFrame.url = url; return Promise.resolve(); }
  }
  const child = new EventEmitter(); child.kill = () => { child.killed = true; child.emit('exit'); };
  startDesktop({ app, BrowserWindow, ipcMain: { handle: (name, fn) => handlers.set(name, fn) },
    shell: { openExternal: url => opened.push(url) },
    dialog: { showErrorBox: (...args) => messages.push(args),
      showMessageBox: async (...args) => { messages.push(args); return { response }; } }
  }, { env: { ASTHA_SERVER_URL: 'https://astha.example.invalid' },
    args: local ? ['--profile=backup'] : [], fork: () => { forks++; return child; } });
  app.emit('ready');
  return { app, windows, messages, opened, handlers, child, forks: () => forks, quits: () => quits };
}
test('all entry points delegate to one runtime; remote startup never starts SQL', () => {
  const fs = require('node:fs');
  assert.match(fs.readFileSync(require.resolve('../src/main/index.js'), 'utf8'), /runtime/);
  const h = harness(); assert.equal(h.forks(), 0); assert.equal(h.app.sandboxed, true);
  assert.equal(h.windows[0].loads[0], 'https://astha.example.invalid');
  const prefs = h.windows[0].options.webPreferences;
  for (const field of ['contextIsolation', 'sandbox', 'webSecurity']) assert.equal(prefs[field], true);
  for (const field of ['nodeIntegration', 'webviewTag', 'allowRunningInsecureContent']) assert.equal(prefs[field], false);
  h.app.emit('second-instance'); assert.equal(h.windows.length, 1); assert.equal(h.windows[0].focused, true);
});
test('navigation, redirects, frames, permissions and webviews fail closed', () => {
  const win = harness().windows[0]; let permission;
  win.permission(null, 'media', x => { permission = x; }); assert.equal(permission, false);
  assert.equal(win.permissionCheck(), false);
  for (const event of ['will-navigate', 'will-redirect', 'will-frame-navigate']) {
    for (const url of ['https://evil.invalid', 'https://astha.example.invalid.evil.invalid', 'file:///private', 'https://u:p@astha.example.invalid']) {
      let blocked = false; win.webContents.emit(event, { preventDefault: () => { blocked = true; } }, url); assert.equal(blocked, true);
    }
    let blocked = false; win.webContents.emit(event, { preventDefault: () => { blocked = true; } }, 'https://astha.example.invalid/app/sistema.html'); assert.equal(blocked, false);
  }
  let blocked = false; win.webContents.emit('will-attach-webview', { preventDefault: () => { blocked = true; } }); assert.equal(blocked, true);
  let frameBlocked = false;
  win.webContents.emit('will-frame-navigate', { url: 'https://astha.example.invalid/app/sistema.html', preventDefault: () => { frameBlocked = true; } });
  assert.equal(frameBlocked, false);
  win.webContents.emit('will-frame-navigate', { url: 'https://evil.invalid', preventDefault: () => { frameBlocked = true; } });
  assert.equal(frameBlocked, true);
});
test('external URLs require HTTPS and explicit native confirmation', async () => {
  const h = harness({ response: 1 }), win = h.windows[0];
  for (const url of ['file:///private', 'javascript:alert(1)', 'https://u:p@example.invalid']) assert.equal(win.open({ url }).action, 'deny');
  assert.equal(h.messages.length, 0);
  assert.equal(win.open({ url: 'https://example.invalid/manual' }).action, 'deny');
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(h.opened, ['https://example.invalid/manual']);
  const denied = harness(); denied.windows[0].open({ url: 'https://example.invalid' });
  await new Promise(resolve => setImmediate(resolve)); assert.deepEqual(denied.opened, []);
});
test('failed main-frame loads offer retry and ignore canceled/subframe loads', async () => {
  const h = harness(), win = h.windows[0];
  win.webContents.emit('did-fail-load', {}, -3, '', '', true);
  win.webContents.emit('did-fail-load', {}, -105, '', '', false); assert.equal(h.messages.length, 0);
  win.webContents.emit('did-fail-load', {}, -105, '', '', true);
  await new Promise(resolve => setImmediate(resolve)); assert.equal(win.loads.length, 2);
  const close = harness({ response: 1 }); close.windows[0].webContents.emit('did-fail-load', {}, -105, '', '', true);
  await new Promise(resolve => setImmediate(resolve)); assert.equal(close.quits(), 1);
});
test('recovery validates child readiness, stops only its child and is unavailable in packaged app', () => {
  const h = harness({ local: true }); assert.equal(h.forks(), 1); assert.equal(h.windows.length, 0);
  for (const port of ['0','65536','443/evil']) h.child.emit('message', { type: 'astha-api-ready', port });
  assert.equal(h.windows.length, 0);
  h.child.emit('message', { type: 'astha-api-ready', port: '3001' });
  assert.equal(h.windows[0].loads[0], 'http://localhost:3001');
  h.app.quit(); assert.equal(h.child.killed, true); assert.equal(h.messages.length, 0);
  const p = harness({ local: true, packaged: true }); assert.equal(p.forks(), 0); assert.equal(p.quits(), 1);
  const exited = harness({ local: true }); exited.child.emit('exit'); assert.equal(exited.quits(), 1);
});
test('second instances do not register IPC or create windows', () => {
  const h = harness({ lock: false }); assert.equal(h.windows.length, 0); assert.equal(h.handlers.size, 0);
});
test('installer contains a client allowlist, ASAR and no backend dependency', () => {
  const config = require('../electron-builder.cjs'), pkg = require('../package.json');
  assert.equal(config.asar, true); assert.equal(pkg.dependencies, undefined);
  assert.ok(config.files.filter(x => !x.startsWith('!')).every(x =>
    x === 'package.json' || /^src\/main\/(index|runtime|window-security|preload|desktop-ipc|dados-store)\.js$/.test(x) ||
    ['src/main/security/client-deployment.js','src/renderer/images/app_icon.png'].includes(x)));
  assert.equal(config.nsis.perMachine, false);
});
