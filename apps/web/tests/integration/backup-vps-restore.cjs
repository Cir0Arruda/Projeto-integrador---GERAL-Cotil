'use strict';
// Explicitly restores a caller-selected, DPAPI-verified backup into disposable MySQL.
// Does not connect to the VPS, active local database, or api/.env.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {startSandbox} = require('./analytics-sandbox');
const backups = require('../../api/tools/backup-snapshots.cjs');
const quote = name => { assert.match(name, /^[a-zA-Z0-9_]{1,64}$/); return '`' + name + '`'; };
function canonical(value) {
  if (value === null || typeof value !== 'object') return value;
  if (Buffer.isBuffer(value)) return {type: 'Buffer', data: [...value]};
  if (Array.isArray(value)) return value.map(canonical);
  return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
}
function hash(row, columns) {
  return crypto.createHash('sha256').update(JSON.stringify(columns.map(column => {
    const value = row[column.COLUMN_NAME];
    if (value === null || value === undefined) return null;
    if (column.DATA_TYPE === 'json') return canonical(typeof value === 'string' ? JSON.parse(value) : value);
    if (['bit','binary','varbinary','tinyblob','blob','mediumblob','longblob'].includes(column.DATA_TYPE)) {
      return Buffer.isBuffer(value) ? value.toString('base64') : value?.type === 'Buffer' ? Buffer.from(value.data).toString('base64') : value;
    }
    return String(value);
  }))).digest('hex');
}
async function main() {
  assert.ok(process.argv[2], 'BACKUP_DIRECTORY_REQUIRED');
  // Verify both independent encrypted containers before starting the restore.
  const snapshot = await backups.verifyBackup(process.argv[2]);
  await backups.verifyBackup(process.argv[2], {copy: 'backup-b.sqlite'});
  const sandbox = await startSandbox({allowRestoreTest: true});
  try {
    const restored = await backups.restoreIntoNewDatabase(sandbox.admin, 'astha_restore_test', snapshot);
    for (const table of snapshot.tables) {
      const columns = table.columns.filter(column => !/(?:VIRTUAL|STORED) GENERATED/.test(String(column.EXTRA)));
      const projection = columns.map(column => ['date','datetime','timestamp','time'].includes(column.DATA_TYPE)
        ? 'CAST(' + quote(column.COLUMN_NAME) + ' AS CHAR) AS ' + quote(column.COLUMN_NAME) : quote(column.COLUMN_NAME)).join(',');
      const [rows] = await sandbox.admin.query('SELECT ' + projection + ' FROM ' + quote(table.name));
      assert.deepEqual(rows.map(row => hash(row, columns)).sort(), table.rows.map(row => hash(row, columns)).sort(), 'RESTORED_DATA_MISMATCH');
    }
    console.log(JSON.stringify({status: 'VPS_BACKUP_RESTORE_VERIFIED', tables: restored.tables,
      rows: restored.rows, allRowHashesEqual: true, disposableDatabase: true, productionChanged: false}));
  } finally { await sandbox.close(); }
}
if (require.main === module) main().catch(() => { console.error('VPS_BACKUP_RESTORE_FAILED'); process.exitCode = 1; });
