'use strict';
// Read-only deployment gate. Manifest contains reviewed source paths/hashes only.
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
let phase = 'manifest';

async function main() {
  const manifest = JSON.parse(await fs.readFile(process.argv[2], 'utf8'));
  assert.match(manifest.release, /^web-\d{4}-\d{2}-\d{2}-\d{2}$/);
  const root = '/opt/astha/releases/' + manifest.release;
  assert.equal(await fs.realpath('/opt/astha/releases/current'), root);
  assert.ok(manifest.files.length > 200);
  for (const file of manifest.files) {
    phase = 'source:' + file.path;
    assert.match(file.path, /^(?:index\.html|app\/[a-zA-Z0-9_./ ()-]+|api\/[a-zA-Z0-9_./-]+)$/);
    assert.ok(!file.path.split('/').some(part => part === '..' || part.startsWith('.')));
    const absolute = path.join(root, file.path);
    assert.equal(await fs.realpath(absolute), absolute);
    const hash = crypto.createHash('sha256').update(await fs.readFile(absolute)).digest('hex');
    assert.equal(hash, file.sha256, file.path);
  }
  phase = 'health';
  const health = await fetch('https://136.111.89.192/api/health', {signal: AbortSignal.timeout(15000)});
  assert.equal(health.status, 200);
  const body = await health.json();
  assert.equal(body.status, 'operational');
  assert.equal(body.database, 'connected');
  assert.equal(body.build, require(root + '/api/security/web-build').fingerprint(root + '/api'));
  const publicPaths = ['app/login.html', 'app/css/app-shell.css', 'app/js/api.js',
    'app/js/sistema-3d-viewer.js', 'app/js/personal-3d.js', 'app/js/settings-org.js',
    'app/vendor/occt-import-js/occt-import-js.wasm'];
  for (const file of publicPaths) {
    phase = 'https:' + file;
    const response = await fetch('https://136.111.89.192/' + file, {signal: AbortSignal.timeout(20000)});
    assert.equal(response.status, 200);
    const sha = crypto.createHash('sha256').update(Buffer.from(await response.arrayBuffer())).digest('hex');
    assert.equal(sha, manifest.files.find(item => item.path === file).sha256, 'HTTPS ' + file);
  }
  for (const file of ['/api/.env', '/.env', '/api/server.js', '/database/schema.sql']) {
    phase = 'private:' + file;
    const response = await fetch('https://136.111.89.192' + file, {signal: AbortSignal.timeout(15000)});
    assert.ok([403, 404].includes(response.status), 'private source exposed');
  }
  for (const [origin, status] of [['http://localhost:7357', 204], ['http://localhost:7358', 403], ['https://example.invalid', 403]]) {
    phase = 'cors:' + origin;
    const response = await fetch('https://136.111.89.192/api/auth/login', {method: 'OPTIONS',
      headers: {Origin: origin, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'authorization,content-type'},
      signal: AbortSignal.timeout(15000)});
    assert.equal(response.status, status, 'CORS ' + origin);
    if (status === 204) assert.equal(response.headers.get('access-control-allow-origin'), origin);
  }
  console.log(JSON.stringify({status: 'RELEASE_VERIFIED', release: manifest.release,
    sourceFiles: manifest.files.length, httpsAssets: publicPaths.length, build: body.build,
    tlsVerified: true, privateFilesDenied: true, flutterWebCors: true}));
}
if (require.main === module) main().catch(() => { console.error('RELEASE_VERIFICATION_FAILED', phase); process.exitCode = 1; });
