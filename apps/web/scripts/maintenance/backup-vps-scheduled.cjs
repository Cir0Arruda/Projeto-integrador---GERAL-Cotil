'use strict';
// Off-VM backup under the signed-in Windows user's DPAPI identity.
const fs = require('node:fs/promises');
const path = require('node:path');
const {spawn} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const DAY = 86400000;
let phase = 'initialization';

function retentionCandidates(items, now = Date.now()) {
  return items.filter(item => Number.isFinite(item.time) && item.time <= now)
    .sort((a, b) => b.time - a.time).slice(30).filter(item => now - item.time > 30 * DAY);
}
async function runBackup(backupRoot) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [path.join(root, 'api/tools/backup-vps.cjs')],
      {cwd: root, env: {...process.env, ASTHA_VPS_BACKUP_ROOT: backupRoot,
        ASTHA_DEPLOY_KEY_PATH: path.join(process.env.USERPROFILE, '.astha-raven-deployment/id_ed25519')},
        windowsHide: true, shell: false, stdio: ['ignore', 'pipe', 'pipe']});
    let output = '', stderr = '', size = 0;
    const timer = setTimeout(() => { child.kill(); reject(Error('SCHEDULED_BACKUP_TIMEOUT')); }, 180000);
    child.stdout.on('data', bytes => { size += bytes.length; if (size > 16384) child.kill(); else output += bytes; });
    // Child errors may contain private paths; emit only the fixed error code below.
    child.stderr.on('data', bytes => { if (stderr.length < 8192) stderr += bytes; });
    child.once('error', () => { clearTimeout(timer); reject(Error('SCHEDULED_BACKUP_START_FAILED')); });
    child.once('close', code => {
      clearTimeout(timer);
      if (code !== 0 || size > 16384) {
        const reason = /Identity file.+not accessible/.test(stderr) ? 'SSH_KEY_UNAVAILABLE'
          : /Host key verification failed/.test(stderr) ? 'SSH_HOST_UNTRUSTED'
          : /Permission denied \(publickey\)/.test(stderr) ? 'SSH_AUTH_FAILED'
          : stderr.match(/VPS_BACKUP_FAILED ([A-Z_]+)(?:\s|$)/)?.[1] || 'SCHEDULED_BACKUP_FAILED';
        return reject(Error(reason));
      }
      try { resolve(JSON.parse(output)); } catch { reject(Error('SCHEDULED_BACKUP_RESULT_INVALID')); }
    });
  });
}
async function main({force = false} = {}) {
  if (process.platform !== 'win32' || !process.env.USERPROFILE) throw Error('WINDOWS_REQUIRED');
  // AppData can be virtualized by packaged Windows hosts. Use an explicit,
  // non-virtualized per-user location shared with Task Scheduler instead.
  const base = path.join(process.env.USERPROFILE, 'ASTHA-RAVEN-Backups/production');
  const stateDirectory = path.join(process.env.USERPROFILE, 'ASTHA-RAVEN-Backups/scheduler');
  await fs.mkdir(stateDirectory, {recursive: true});
  const stateFile = path.join(stateDirectory, 'last-success.json');
  let previous;
  try { previous = JSON.parse(await fs.readFile(stateFile, 'utf8')); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (!force && previous?.status === 'VPS_BACKUP_VERIFIED' && Date.now() - Date.parse(previous.completedAt) < 20 * 3600000) {
    console.log('SCHEDULED_BACKUP_ALREADY_CURRENT'); return;
  }
  phase = 'capture';
  const result = await runBackup(base);
  phase = 'verify-result';
  if (result.status !== 'VPS_BACKUP_VERIFIED' || result.copies !== 2 || result.encrypted !== true || result.tables < 1) throw Error('SCHEDULED_BACKUP_UNVERIFIED');
  phase = 'verify-path';
  const resolvedBase = await fs.realpath(base), resolved = await fs.realpath(result.directory);
  if (path.dirname(resolved) !== resolvedBase || !/^vps-production-\d{4}-\d{2}-\d{2}T[0-9TZ-]+$/.test(path.basename(resolved))) throw Error('SCHEDULED_BACKUP_PATH_INVALID');
  const marker = {kind: 'astha-scheduled-backup-v1', completedAt: new Date().toISOString()};
  phase = 'save-state';
  await fs.writeFile(path.join(resolved, 'scheduled.json'), JSON.stringify(marker), {flag: 'wx'});
  const state = {...result, ...marker};
  await fs.writeFile(stateFile + '.tmp', JSON.stringify(state, null, 2));
  await fs.rename(stateFile + '.tmp', stateFile);
  // Preserve all manual/migration snapshots, damaged snapshots, and at least 30 scheduled copies.
  phase = 'retention';
  const snapshots = [];
  for (const entry of await fs.readdir(base, {withFileTypes: true})) {
    if (!entry.isDirectory() || entry.isSymbolicLink() || !/^vps-production-\d{4}-\d{2}-\d{2}T[0-9TZ-]+$/.test(entry.name)) continue;
    const directory = path.join(base, entry.name);
    try {
      const record = JSON.parse(await fs.readFile(path.join(directory, 'scheduled.json'), 'utf8'));
      if (record.kind === marker.kind) snapshots.push({directory, time: Date.parse(record.completedAt)});
    } catch { /* unmarked snapshots are never subject to retention */ }
  }
  let pruned = 0;
  for (const candidate of retentionCandidates(snapshots)) {
    const real = await fs.realpath(candidate.directory);
    if (path.dirname(real) !== resolvedBase || real !== candidate.directory) throw Error('BACKUP_RETENTION_PATH_INVALID');
    const backup = require('../../api/tools/backup-snapshots.cjs');
    try { for (const copy of ['backup-a.sqlite', 'backup-b.sqlite']) await backup.verifyBackup(real, {copy}); }
    catch { continue; }
    await fs.rm(real, {recursive: true}); pruned++;
  }
  console.log(JSON.stringify({status: result.status, tables: result.tables, rows: result.rows,
    copies: 2, encrypted: true, offVm: true, scheduled: true, pruned}));
}
if (require.main === module) main({force: process.argv.includes('--force')}).catch(async error => {
  const reason = /^[A-Z_]+$/.test(error.code || error.message) ? error.code || error.message : 'REVIEW_REQUIRED';
  const state = {status: 'SCHEDULED_BACKUP_FAILED', phase, reason, failedAt: new Date().toISOString()};
  if (process.env.USERPROFILE) await fs.writeFile(path.join(process.env.USERPROFILE, 'ASTHA-RAVEN-Backups/scheduler/last-failure.json'), JSON.stringify(state)).catch(() => {});
  console.error(state.status, phase, reason);
  process.exitCode = 1;
});
module.exports = {retentionCandidates};
