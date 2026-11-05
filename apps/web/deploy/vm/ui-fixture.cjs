'use strict';
// Administrative, temporary tenant for deployment UI validation only.
// Credentials are returned only over the caller's authenticated SSH pipe.
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const load = createRequire('/opt/astha/releases/current/api/package.json');
async function main() {
  if (process.getuid?.() !== 0) throw Error('ADMIN_REQUIRED');
  const db = await load('mysql2/promise').createConnection({socketPath: '/run/mysqld/mysqld.sock', user: 'root', database: 'astha_raven_prod'});
  try {
    if (process.argv[2] === 'create') {
      const mode = process.argv[3];
      if (!['corporate', 'personal'].includes(mode)) throw Error('INVALID_MODE');
      const org = 'vps_ui_' + crypto.randomBytes(10).toString('hex');
      const email = org + '@example.invalid', password = crypto.randomBytes(24).toString('hex');
      await db.beginTransaction();
      try {
        await db.execute('INSERT INTO organizations(id,name,workspace_type,setup_done) VALUES(?,?,?,1)', [org, 'Temporary deployment UI verification', mode]);
        await db.execute('INSERT INTO users(name,email,password_hash,role,org_id,is_active,setup_done) VALUES(?,?,?,?,?,1,1)', ['Temporary deployment UI verification', email, await load('bcryptjs').hash(password, 12), 'admin', org]);
        await db.commit();
      } catch (error) { await db.rollback(); throw error; }
      process.stdout.write(JSON.stringify({org, email, password}));
    } else if (process.argv[2] === 'cleanup') {
      let input = '';
      for await (const chunk of process.stdin) { input += chunk; if (input.length > 1000) throw Error('INPUT_LIMIT'); }
      const {org} = JSON.parse(input);
      if (!/^vps_ui_[a-f0-9]{20}$/.test(org)) throw Error('INVALID_FIXTURE');
      const [tenants] = await db.execute('SELECT id FROM organizations WHERE id=? AND name=?', [org, 'Temporary deployment UI verification']);
      if (tenants.length !== 1) throw Error('FIXTURE_NOT_FOUND');
      await db.beginTransaction();
      try {
        await db.execute('DELETE FROM mobile_sync_receipts WHERE org_id=?', [org]);
        await db.execute('DELETE FROM movement_valuation WHERE org_id=?', [org]);
        await db.execute('DELETE m FROM movements m JOIN materials t ON t.id=m.material_id WHERE t.org_id=?', [org]);
        for (const table of ['materials','warehouse_context','warehouses','warehouse_layout','org_profile_design']) {
          await db.execute('DELETE FROM `' + table + '` WHERE org_id=?', [org]);
        }
        await db.execute('DELETE s FROM sessions s JOIN users u ON u.id=s.user_id WHERE u.org_id=?', [org]);
        await db.execute('DELETE a FROM audit_log a JOIN users u ON u.id=a.user_id WHERE u.org_id=?', [org]);
        await db.execute('DELETE FROM users WHERE org_id=?', [org]);
        await db.execute('DELETE FROM organizations WHERE id=? AND name=?', [org, 'Temporary deployment UI verification']);
        await db.commit();
      } catch (error) { await db.rollback(); throw error; }
      process.stdout.write(JSON.stringify({status: 'UI_FIXTURE_REMOVED'}));
    } else if (process.argv[2] === 'cleanup-orphan-fixtures') {
      // Only orphan rows from our random synthetic namespaces, whose tenant is gone.
      const [result] = await db.execute("DELETE v FROM movement_valuation v LEFT JOIN movements m ON m.id=v.movement_id LEFT JOIN organizations o ON BINARY o.id=BINARY v.org_id WHERE m.id IS NULL AND o.id IS NULL AND (v.org_id REGEXP '^vps_ui_[a-f0-9]{20}$' OR v.org_id REGEXP '^vps_smoke_[a-f0-9]{20}$')");
      process.stdout.write(JSON.stringify({status: 'ORPHAN_FIXTURES_REMOVED', rows: result.affectedRows}));
    } else if (process.argv[2] === 'verify-clean') {
      const [[tenants]] = await db.execute("SELECT COUNT(*) AS n FROM organizations WHERE name='Temporary deployment UI verification' OR name='Temporary VPS validation'");
      const [[valuations]] = await db.execute("SELECT COUNT(*) AS n FROM movement_valuation WHERE LEFT(org_id,7)='vps_ui_' OR LEFT(org_id,10)='vps_smoke_'");
      const [[orphans]] = await db.execute('SELECT COUNT(*) AS n FROM movement_valuation v LEFT JOIN movements m ON m.id=v.movement_id WHERE m.id IS NULL');
      process.stdout.write(JSON.stringify({syntheticTenants: tenants.n, syntheticValuations: valuations.n, orphanValuations: orphans.n}));
      if (tenants.n || valuations.n) process.exitCode = 1;
    } else throw Error('INVALID_ACTION');
  } finally { await db.end(); }
}
if (require.main === module) main().catch(error => {
  console.error('DEPLOYMENT_UI_FIXTURE_FAILED', /^[A-Z0-9_]+$/.test(error.code || '') ? error.code : 'VALIDATION_FAILED');
  process.exitCode = 1;
});
