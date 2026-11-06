'use strict';
// Explicit acceptance flow; requires the coordinator's disposable tcc-app-sandbox.
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const qa = path.join(root, 'tests/.runtime');
const {existsSync} = require('node:fs');
const {chromium, _electron} = require(process.env.ASTHA_PLAYWRIGHT_PACKAGE || path.join(qa, 'ui-python/playwright/driver/package'));
const desktopRoot = process.env.ASTHA_TCC_DESKTOP_ROOT || (existsSync(path.join(root, 'electron/src/main/runtime.js'))
  ? path.join(root, 'electron') : path.resolve(root, '../desktop'));
const mobileRoot = process.env.ASTHA_TCC_MOBILE_ROOT || (existsSync(path.resolve(root, '../COTIL/astha_app/pubspec.yaml'))
  ? path.resolve(root, '../COTIL/astha_app') : path.resolve(root, '../mobile'));
let phase = 'fixtures';
async function login(page, base, user) {
  await page.goto(base + '/app/login.html', {waitUntil: 'networkidle'});
  await page.getByLabel('E-mail', {exact: true}).fill(user.email);
  await page.locator('#password').fill(user.password);
  await page.getByRole('button', {name: 'Entrar', exact: true}).click();
  await page.waitForURL('**/app/home.html', {timeout: 30000});
  await page.waitForLoadState('networkidle');
}
async function api(page, method, url, body) {
  return page.evaluate(async ({method, url, body}) => {
    const response = await fetch('/api' + url, {method, headers: {
      Authorization: 'Bearer ' + localStorage.getItem('astha_token'), 'Content-Type': 'application/json'},
      ...(body ? {body: JSON.stringify(body)} : {})});
    return {status: response.status, body: await response.json()};
  }, {method, url, body});
}
async function visibleQuantity(page, code, quantity) {
  await page.waitForFunction(({code, quantity}) => {
    const row = [...document.querySelectorAll('#stockTableBody tr')].find(item => item.querySelector('.material-code')?.textContent === code);
    return row && Number(row.children[6].textContent.replaceAll('.', '').replace(',', '.')) === quantity;
  }, {code, quantity}, {timeout: 15000});
}
async function flutter(phase, statePath, fixturePath) {
  const log = path.join(qa, 'tcc-cross-flutter-' + phase + '.log');
  const args = ['test', 'test/tcc_live_api_test.dart', '--no-pub', '--reporter', 'expanded',
    '--dart-define=ASTHA_TCC_FIXTURES=' + fixturePath, '--dart-define=ASTHA_TCC_STATE=' + statePath,
    '--dart-define=ASTHA_TCC_PHASE=' + phase];
  // Use Dart directly to avoid cmd.exe quoting/interpolation around project paths.
  const sdk = process.env.FLUTTER_ROOT || path.join(process.env.USERPROFILE, 'develop/flutter');
  const exe = path.join(sdk, 'bin/cache/dart-sdk/bin/dart.exe');
  const snapshot = path.join(sdk, 'bin/cache/flutter_tools.snapshot');
  await new Promise((resolve, reject) => {
    const child = spawn(exe, [snapshot, ...args], {cwd: mobileRoot, windowsHide: true, shell: false, stdio: ['ignore','pipe','pipe']});
    let output = ''; child.stdout.on('data', data => { output += data; }); child.stderr.on('data', data => { output += data; });
    const timer = setTimeout(() => {child.kill(); reject(Error('FLUTTER_ACCEPTANCE_TIMEOUT'));}, 180000);
    child.once('error', () => {clearTimeout(timer); reject(Error('FLUTTER_ACCEPTANCE_START_FAILED'));});
    child.once('close', async code => {clearTimeout(timer); await fs.writeFile(log, output); code === 0 ? resolve() : reject(Error('FLUTTER_ACCEPTANCE_FAILED'));});
  });
}
async function main() {
  const fixturePath = path.join(qa, 'tcc-app-fixtures.json');
  const fixtures = JSON.parse(await fs.readFile(fixturePath, 'utf8'));
  assert.equal(fixtures.base, 'http://127.0.0.1:3001'); assert.equal(fixtures.companies, 4);
  const browser = await chromium.launch({headless: true});
  const context = await browser.newContext({viewport: {width: 1440, height: 960}, locale: 'pt-BR'});
  const page = await context.newPage();
  const owner = fixtures.accounts.find(a => a.org_id === 'tcc-alpha' && a.role === 'superadmin');
  const operator = fixtures.accounts.find(a => a.org_id === 'tcc-alpha' && a.role === 'operator');
  const profile = await fs.mkdtemp(path.join(qa, 'tcc-electron-profile-'));
  let desktop;
  const errors = [];
  try {
    phase = 'web-login';
    page.on('pageerror', () => errors.push('WEB_PAGE_EXCEPTION'));
    await login(page, fixtures.base, owner);
    phase = 'warehouse';
    let warehouses = (await api(page, 'GET', '/warehouse/tabs')).body;
    if (!warehouses.length) {
      const created = await api(page, 'POST', '/warehouse/tabs', {name: 'Cross-client synthetic warehouse'});
      assert.equal(created.status, 201); warehouses = [created.body];
    }
    const code = 'TCC-' + Date.now();
    phase = 'web-material';
    const material = await api(page, 'POST', '/materials', {code, description: 'Synthetic Web Electron Flutter',
      quantity: 1.25, unit_price: 12.34, warehouse_id: warehouses[0].id});
    assert.equal(material.status, 201); assert.equal(Number(material.body.quantity), 1.25);
    await page.goto(fixtures.base + '/app/sistema.html?tab=estoque', {waitUntil: 'networkidle'});
    await page.locator('#stockFilter').fill(code);
    await visibleQuantity(page, code, 1.25);
    phase = 'electron-launch';
    desktop = await _electron.launch({executablePath: require(require.resolve('electron', {paths: [desktopRoot, root]})),
      args: [path.join(__dirname, 'tcc-electron-bootstrap.cjs')], cwd: root,
      env: {...process.env, ASTHA_QA_PROFILE: profile, ASTHA_TCC_DESKTOP_ROOT: desktopRoot}});
    const window = await desktop.firstWindow();
    window.on('pageerror', () => errors.push('ELECTRON_PAGE_EXCEPTION'));
    phase = 'electron-login';
    await login(window, 'http://localhost:3001', operator);
    phase = 'electron-security';
    const info = await window.evaluate(() => window.asthaDesktop.getRuntimeInfo());
    assert.equal(info.local, true); assert.equal(info.serverUrl, 'http://localhost:3001');
    const prefs = await desktop.evaluate(({BrowserWindow}) => BrowserWindow.getAllWindows()[0].webContents.getLastWebPreferences());
    for (const key of ['sandbox','contextIsolation','webSecurity']) assert.equal(prefs[key], true);
    assert.equal(prefs.nodeIntegration, false);
    phase = 'electron-stock';
    await window.goto('http://localhost:3001/app/sistema.html?tab=estoque', {waitUntil: 'networkidle'});
    assert.equal(Number((await api(window, 'GET', '/materials/' + code)).body.quantity), 1.25);
    await window.getByRole('button', {name: 'Entrada (+)', exact: true}).click();
    await window.locator('#entryCode').fill(code); await window.locator('#entryQty').fill('1.25');
    await window.locator('#entryPrice').fill('12.34');
    const response = window.waitForResponse(r => r.url().includes('/api/movements/entry') && r.request().method() === 'POST');
    await window.getByRole('button', {name: 'Registrar Entrada', exact: true}).click();
    assert.equal((await response).status(), 201);
    await window.getByRole('button', {name: 'Estoque', exact: true}).click();
    await window.locator('#stockFilter').fill(code);
    await visibleQuantity(page, code, 2.5);
    await visibleQuantity(window, code, 2.5);
    assert.equal(Number((await api(page, 'GET', '/materials/' + code)).body.quantity), 2.5);
    const statePath = path.join(qa, 'tcc-cross-client-state.json');
    await fs.writeFile(statePath, JSON.stringify({code, expected: 2.5}));
    phase = 'flutter-write';
    await flutter('write', statePath, fixturePath);
    const state = JSON.parse(await fs.readFile(statePath, 'utf8'));
    assert.equal(Number((await api(window, 'GET', '/materials/' + code)).body.quantity), 2.375);
    assert.equal(Number((await api(page, 'GET', '/materials/' + state.flutterCode)).body.quantity), 3.125);
    await visibleQuantity(page, code, 2.375);
    await visibleQuantity(window, code, 2.375);
    phase = 'editor-preservation';
    const warehouse = await page.evaluate(() => currentWarehouseId);
    await page.locator('#stockTableBody tr').filter({hasText: code}).locator('[data-action="edit"]').click();
    await page.locator('#matDesc').fill('UNSAVED cross-client draft');
    phase = 'external-entry-during-editor';
    assert.equal((await api(window, 'POST', '/movements/entry', {code, quantity: .625})).status, 201);
    await page.waitForTimeout(6000);
    phase = 'editor-draft-value';
    assert.equal(await page.locator('#matDesc').inputValue(), 'UNSAVED cross-client draft');
    phase = 'editor-table-paused';
    try { await visibleQuantity(page, code, 2.375); }
    catch (error) {
      console.log(JSON.stringify(await page.evaluate(code => ({gate: 'editor-table-paused',
        modal: document.getElementById('materialModal').classList.contains('active'),
        live: document.getElementById('stockLiveStatus')?.dataset.state,
        filter: document.getElementById('stockFilter').value,
        quantity: [...document.querySelectorAll('#stockTableBody tr')].find(row => row.querySelector('.material-code')?.textContent === code)?.children[6].textContent,
        hidden: document.hidden}), code)));
      throw error;
    }
    phase = 'editor-close';
    await page.locator('#materialModal .eo-modal-close').click();
    phase = 'web-table-resume';
    await visibleQuantity(page, code, 3);
    phase = 'electron-table-resume';
    await visibleQuantity(window, code, 3);
    phase = 'filter-preserved';
    assert.equal(await page.locator('#stockFilter').inputValue(), code);
    assert.equal(await window.locator('#stockFilter').inputValue(), code);
    assert.equal(await page.evaluate(() => currentWarehouseId), warehouse);
    await fs.writeFile(statePath, JSON.stringify({...state, expected: 3}));
    phase = 'flutter-verify';
    await flutter('verify', statePath, fixturePath);
    await window.screenshot({path: path.join(qa, 'tcc-electron-stock.png'), fullPage: true});
    for (const company of ['tcc-beta','tcc-gamma','tcc-delta']) {
      const c = await browser.newContext(); const p = await c.newPage();
      try { await login(p, fixtures.base, fixtures.accounts.find(a => a.org_id === company && a.role === 'superadmin'));
        assert.equal((await api(p, 'GET', '/materials/' + code)).status, 404);
      } finally { await c.close(); }
    }
    assert.deepEqual(errors, []);
    const result = {status: 'TCC_CROSS_CLIENTS_PASSED', companies: 4, runtime: 'Electron real + Chromium + Flutter repositories',
      sharedMaterialFinalQuantity: 3, flutterCreatedQuantity: 3.125, electronSandbox: true, ipcTrustedOrigin: true,
      tenantIsolation: true, liveTables: true, searchAndWarehousePreserved: true, unsavedEditorPreserved: true,
      pageErrors: errors.length, productionTouched: false};
    await fs.writeFile(path.join(qa, 'tcc-cross-clients-result.json'), JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result));
  } finally {
    await desktop?.close(); await context.close(); await browser.close();
    const real = await fs.realpath(profile); if (path.dirname(real) !== await fs.realpath(qa) || !path.basename(real).startsWith('tcc-electron-profile-')) throw Error('PROFILE_CLEANUP_REJECTED');
    await fs.rm(real, {recursive: true, force: true, maxRetries: 4, retryDelay: 300});
  }
}
if (require.main === module) main().catch(error => {console.error('TCC_CROSS_CLIENTS_FAILED', phase, error.name, /^[A-Z_]+$/.test(error.message) ? error.message : 'ASSERTION_FAILED'); process.exitCode = 1;});
