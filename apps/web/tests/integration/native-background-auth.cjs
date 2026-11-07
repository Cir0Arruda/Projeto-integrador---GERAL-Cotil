'use strict';
// Real API/MySQL and native worker acceptance, using only a new owned sandbox.
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const { randomBytes, randomUUID } = require('node:crypto');
const { spawn } = require('node:child_process');
const { startAuditApp } = require('./audit-app-sandbox.cjs');
const base = 'http://127.0.0.1:3001';
const org = 'audit-native';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let phase = 'guard';

async function main({ selftest = false } = {}) {
  if (!selftest && (process.platform !== 'linux' || process.env.GITHUB_ACTIONS !== 'true' ||
      process.env.ASTHA_ISOLATED_NATIVE_QA !== 'true')) throw Error('OWNED_CI_EMULATOR_REQUIRED');
  const password = randomBytes(30).toString('hex');
  let app, token = '', privateDir, reverse = false;
  const operation = randomUUID();
  const childEnv = Object.fromEntries(Object.entries(process.env).filter(([key]) =>
    ['PATH','SystemRoot','WINDIR','COMSPEC','HOME','USER','USERPROFILE','LOCALAPPDATA','APPDATA',
      'TEMP','TMP','TMPDIR','ANDROID_HOME','ANDROID_SDK_ROOT','ANDROID_USER_HOME',
      'ANDROID_AVD_HOME','ANDROID_EMULATOR_HOME','JAVA_HOME','LANG','CI','FLUTTER_ROOT',
      'PUB_CACHE','GRADLE_USER_HOME','TERM'].includes(key)));
  const redact = text => String(text).split(password).join('[redacted]').split(token || '\0').join('[redacted]');
  function command(executable, args, { cwd, timeout = 15000, log = false, allowFailure = false } = {}) {
    return new Promise((resolve, reject) => {
      const child = spawn(executable, args, { cwd, env: childEnv, windowsHide: true, stdio: ['ignore','pipe','pipe'] });
      let output = '', exceeded = false;
      const receive = data => {
        if (output.length + data.length > 2 * 1024 * 1024) { exceeded = true; child.kill(); return; }
        output += data.toString();
        if (log) process.stdout.write(redact(data.toString()));
      };
      child.stdout.on('data', receive); child.stderr.on('data', receive);
      const timer = setTimeout(() => { child.kill(); reject(Error('QA_CHILD_TIMEOUT')); }, timeout);
      child.once('error', error => { clearTimeout(timer); reject(error); });
      child.once('close', code => {
        clearTimeout(timer);
        if (exceeded) return reject(Error('QA_CHILD_OUTPUT_LIMIT'));
        if (code !== 0 && !allowFailure) return reject(Error('QA_CHILD_FAILED'));
        resolve({ code, output });
      });
    });
  }
  const adb = (args, options) => command(path.join(process.env.ANDROID_HOME || '', 'platform-tools/adb'), ['-s','emulator-5554',...args], options);
  async function request(method, endpoint, body, auth = true) {
    const response = await fetch(base + '/api' + endpoint, {
      method, redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: 'Bearer ' + token } : {}) },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const result = await response.json();
    assert.ok(response.status >= 200 && response.status < 300, 'QA API status ' + response.status);
    return result;
  }
  async function state() {
    const [[stock]] = await app.pool.execute('SELECT quantity FROM materials WHERE org_id=? AND code=?', [org,'NATIVE-BG-QA']);
    const [[receipts]] = await app.pool.execute('SELECT COUNT(*) AS n FROM mobile_sync_receipts WHERE org_id=? AND user_id=? AND operation_id=?', [org,app.accounts[0].id,operation]);
    const [[movements]] = await app.pool.execute('SELECT COUNT(*) AS n FROM movements m JOIN materials t ON t.id=m.material_id WHERE t.org_id=? AND t.code=?', [org,'NATIVE-BG-QA']);
    return { quantity: Number(stock.quantity), receipts: Number(receipts.n), movements: Number(movements.n) };
  }
  async function preferences() {
    const r = await adb(['shell','run-as','com.astharaven.astha_app','cat','shared_prefs/FlutterSharedPreferences.xml'], { allowFailure: true });
    return r.code === 0 ? r.output : '';
  }
  function pref(xml, name) {
    const tag = xml.match(new RegExp('<(?:boolean|long|int)\\b[^>]*name="flutter\\.' + name + '"[^>]*>'))?.[0];
    return tag?.match(/\bvalue="([^"]*)"/)?.[1];
  }
  async function waitFor(check, seconds = 150) {
    const until = Date.now() + seconds * 1000;
    do { if (await check()) return; await delay(1500); } while (Date.now() < until);
    throw Error('QA_CONDITION_TIMEOUT');
  }
  try {
    phase = 'isolated-api';
    app = await startAuditApp({ port: 3001, password, fixtures: [{ id: org, type: 'corporate' }] });
    assert.match(app.db, /^astha_test_[a-f0-9]+$/);
    phase = 'fixture-login';
    const login = await request('POST','/auth/login',{ email: app.accounts[0].email, password },false);
    assert.equal(typeof login.token, 'string'); token = login.token;
    const warehouse = await request('POST','/warehouse/tabs',{ name: 'Native background fixture' });
    await request('POST','/materials',{ code: 'NATIVE-BG-QA', description: 'Synthetic native background fixture', quantity: 0, min_qty: 0, max_qty: 5, unit_price: 10, unit: 'UN', warehouse_id: warehouse.id });
    assert.deepEqual(await state(), { quantity: 0, receipts: 0, movements: 0 });
    if (selftest) {
      const op = { id: operation, method: 'POST', path: '/api/movements/entry', body: { code: 'NATIVE-BG-QA', quantity: 1.125 } };
      await request('POST','/sync/operations',op); await request('POST','/sync/operations',op);
      assert.deepEqual(await state(), { quantity: 1.125, receipts: 1, movements: 1 });
      console.log('NATIVE_BACKGROUND_FIXTURE_SELFTEST_PASSED (backend only; no native execution claim)');
      return;
    }
    phase = 'private-build-input';
    const mobile = path.resolve(process.env.ASTHA_TEST_MOBILE_DIR || path.join(__dirname,'../../../mobile'));
    const manifest = await fs.readFile(path.join(mobile,'pubspec.yaml'),'utf8');
    assert.match(manifest, /^name: astha_app\s*$/m);
    privateDir = await fs.mkdtemp(path.join(app.workspace,'native-auth-'));
    const defines = path.join(privateDir,'defines.json');
    await fs.writeFile(defines,JSON.stringify({ ASTHA_ISOLATED_NATIVE_QA: 'true', ASTHA_API_URL: base, ASTHA_NATIVE_QA_TOKEN: token, ASTHA_NATIVE_QA_OPERATION: operation }),{ mode: 0o600, flag: 'wx' });
    phase = 'native-build';
    // Compiler output is kept private: it can contain encoded Dart defines.
    console.log('AUTHENTICATED_NATIVE_BUILD_STARTED');
    await command('flutter',['build','apk','--debug','--no-pub','-t','integration_test/authenticated_background_probe_app.dart','--dart-define-from-file='+defines],{ cwd: mobile, timeout: 12*60*1000 });
    await fs.unlink(defines);
    phase = 'emulator-start';
    await adb(['reverse','tcp:3001','tcp:3001']); reverse = true;
    await adb(['install',path.join(mobile,'build/app/outputs/flutter-apk/app-debug.apk')],{ timeout: 120000 });
    await adb(['logcat','-c']);
    await adb(['shell','am','start','-W','-n','com.astharaven.astha_app/.MainActivity'],{ timeout: 60000 });
    await waitFor(async () => pref(await preferences(),'qa_authenticated_scheduled') === 'true');
    assert.deepEqual(await state(), { quantity: 0, receipts: 0, movements: 0 });
    await adb(['shell','input','keyevent','KEYCODE_HOME']);
    await waitFor(async () => { await adb(['shell','am','kill','com.astharaven.astha_app']); return (await adb(['shell','pidof','com.astharaven.astha_app'],{ allowFailure: true })).code !== 0; },30);
    const exitedAt = Date.now();
    const before = pref(await preferences(),'qa_background_completed_at');
    phase = 'authenticated-cold-worker';
    await waitFor(async () => {
      const prefs = await preferences();
      const marker = pref(prefs,'qa_background_completed_at');
      return marker && marker !== before && Number(marker) >= exitedAt && pref(prefs,'qa_background_success') === 'true';
    });
    assert.deepEqual(await state(), { quantity: 1.125, receipts: 1, movements: 1 });
    phase = 'native-queue-reopen';
    await adb(['shell','am','start','-W','-n','com.astharaven.astha_app/.MainActivity'],{ timeout: 60000 });
    await waitFor(async () => pref(await preferences(),'qa_authenticated_verified') === 'true',45);
    assert.equal(pref(await preferences(),'qa_authenticated_remaining'),'0');
    assert.deepEqual(await state(), { quantity: 1.125, receipts: 1, movements: 1 });
    const result = { status: 'AUTHENTICATED_NATIVE_BACKGROUND_PASSED', isolatedMySQL: true, realApi: true, realSession: true, uiProcessExited: true, osDeliveredWorker: true, quantity: 1.125, receipts: 1, movements: 1, pendingOnReopen: 0, physicalBiometrics: 'not tested' };
    const evidence = process.env.ASTHA_NATIVE_EVIDENCE_DIR;
    if (evidence) {
      const evidencePath = await fs.realpath(evidence), runner = await fs.realpath(process.env.RUNNER_TEMP);
      if (path.dirname(evidencePath) !== runner || path.basename(evidencePath) !== 'astha-authenticated-native-qa') throw Error('QA_EVIDENCE_PATH_REJECTED');
      await fs.writeFile(path.join(evidencePath,'result.json'),JSON.stringify(result,null,2)+'\n');
    }
    console.log(JSON.stringify(result));
  } finally {
    if (!selftest) {
      await adb(['shell','am','force-stop','com.astharaven.astha_app'],{ allowFailure: true }).catch(()=>{});
      if (reverse) await adb(['reverse','--remove','tcp:3001'],{ allowFailure: true }).catch(()=>{});
    }
    if (app) await app.close();
  }
}
if (require.main === module) main({ selftest: process.argv.includes('--selftest') }).catch(error => {
  console.error('NATIVE_BACKGROUND_AUTH_FAILED',phase,/^[A-Z0-9_]+$/.test(error.code || '') ? error.code : 'VALIDATION_FAILED');
  process.exitCode = 1;
});
module.exports = { main };
