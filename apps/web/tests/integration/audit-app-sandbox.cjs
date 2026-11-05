'use strict';
// Full application QA against a new disposable MySQL process. Never uses app data.
const {startSandbox}=require('./analytics-sandbox');
const bcrypt=require('../../api/node_modules/bcryptjs');
async function main(){
 const sandbox=await startSandbox();let server,closing=false;
 async function close(){if(closing)return;closing=true;if(server){server.closeAllConnections();await new Promise(r=>server.close(r));}await sandbox.close();console.log('AUDIT_APP_STOPPED');}
 try{
  const {admin,pool,db}=sandbox;
  if(!/^astha_test_[a-f0-9]+$/.test(db))throw Error('SANDBOX_REQUIRED');
  // Temporary bootstrap DDL is revoked before any HTTP request can arrive.
  await admin.query('GRANT CREATE,ALTER,INDEX,REFERENCES ON '+db+".* TO 'astha_test'@'127.0.0.1'");
  await require('../../api/database/migrate_orgs').runOrgMigration();
  const [userColumns]=await admin.query('SHOW COLUMNS FROM users');
  for(const [column,definition] of [['dob','DATE NULL'],['gender','VARCHAR(30) NULL'],['country','VARCHAR(100) NULL']])if(!userColumns.some(c=>c.Field===column))await admin.query('ALTER TABLE users ADD COLUMN '+column+' '+definition);
  await require('../../api/database/ensure_org_workspace')();
  await admin.query('CREATE TABLE IF NOT EXISTS warehouses(id INT AUTO_INCREMENT PRIMARY KEY,org_id VARCHAR(50) NOT NULL,name VARCHAR(100) NOT NULL,tab_number INT DEFAULT 1,is_shared TINYINT DEFAULT 0,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB');
  await admin.query('CREATE TABLE IF NOT EXISTS warehouse_shares(warehouse_id INT NOT NULL,shared_with_org_id VARCHAR(50) NOT NULL,PRIMARY KEY(warehouse_id,shared_with_org_id)) ENGINE=InnoDB');
  const [layoutColumns]=await admin.query('SHOW COLUMNS FROM warehouse_layout');
  for(const [column,definition] of [['org_id','VARCHAR(50) NULL'],['blueprint_data','LONGTEXT NULL']])if(!layoutColumns.some(c=>c.Field===column))await admin.query('ALTER TABLE warehouse_layout ADD COLUMN '+column+' '+definition);
  await require('../../api/database/warehouse-context').upgrade(admin);
  await require('../../api/database/migrate_mobile_sync').migrateMobileSync(admin);
  await require('../../api/database/migrate_material_code_scope').migrateMaterialCodeScope(admin);
  await require('../../api/database/migrate_components_org').migrateComponentsOrg(admin);
  await admin.query('REVOKE CREATE,ALTER,INDEX,REFERENCES ON '+db+".* FROM 'astha_test'@'127.0.0.1'");
  const [tables]=await admin.query('SHOW TABLES');
  for(const row of tables){const table=Object.values(row)[0];if(!/^[a-z_]+$/.test(table))throw Error('INVALID_TABLE');await admin.query('GRANT SELECT,INSERT,UPDATE,DELETE ON '+db+'.'+table+" TO 'astha_test'@'127.0.0.1'");}
  const hash=await bcrypt.hash('Auditoria Sintetica 2026!',10);
  for(const [id,type] of [['audit-corporate','corporate'],['audit-personal','personal']]){
   await pool.execute('INSERT INTO organizations(id,name,workspace_type,setup_done) VALUES(?,?,?,1)',[id,'Espaço sintético de auditoria',type]);
   await pool.execute('INSERT INTO users(name,surname,email,password_hash,role,org_id,is_active,setup_done) VALUES(?,?,?,?,?,?,1,1)',['Auditoria','Sintética',id+'@example.invalid',hash,'admin',id]);
  }
  process.env.PORT='5183';process.env.NODE_ENV='test';process.env.ALLOWED_ORIGINS='http://127.0.0.1:5183';
  // startSandbox swaps the bootstrap pool; health must use that runtime pool too.
  require('../../api/database/connection').testConnection=async()=>{try{await pool.execute('SELECT 1');return true;}catch{return false;}};
  const {app}=require('../../api/server');
  server=await new Promise((resolve,reject)=>{const s=app.listen(5183,'127.0.0.1',()=>resolve(s));s.on('error',reject);});
  console.log('AUDIT_APP_READY http://127.0.0.1:5183');
  const stop=()=>close().catch(()=>{process.exitCode=1;});
  process.on('SIGINT',stop);process.on('SIGTERM',stop);
  process.stdin.on('data',data=>{if(String(data).trim()==='stop')stop();});
  setTimeout(stop,60*60*1000).unref();
 }catch(error){console.error('AUDIT_APP_FAILED',error.code||error.message);await close();process.exitCode=1;}
}
if(require.main===module)main();
