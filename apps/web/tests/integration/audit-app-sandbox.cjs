'use strict';
// Full application QA against a new disposable MySQL process. Never uses app data.
const {startSandbox}=require('./analytics-sandbox');
const bcrypt=require('../../api/node_modules/bcryptjs');
async function startAuditApp({port=5183,fixtures=[{id:'audit-corporate',type:'corporate'},{id:'audit-personal',type:'personal'}],password='Auditoria Sintetica 2026!'}={}){
 if(![3001,5183].includes(port))throw Error('AUDIT_LOOPBACK_PORT_REQUIRED');
 const sandbox=await startSandbox();let server,closing=false,stopAnalytics=()=>{};
 async function close(){if(closing)return;closing=true;stopAnalytics();if(server){server.closeAllConnections();await new Promise(r=>server.close(r));}await sandbox.close();process.stdin.pause();process.stdin.unref?.();console.log('AUDIT_APP_STOPPED');}
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
  // The reference schema predates material attachments. Provision this table
  // before runtime grants so detail views do not get a fixture-only SQL denial.
  await admin.query(`CREATE TABLE IF NOT EXISTS material_files (
   id INT AUTO_INCREMENT PRIMARY KEY,material_id INT NOT NULL,
   category ENUM('product_3d','machinery_3d','manual','electrical','mechanical','other') NOT NULL DEFAULT 'other',
   filename VARCHAR(500) NOT NULL,mime_type VARCHAR(100),file_data LONGTEXT,file_url VARCHAR(1000),
   description VARCHAR(500),file_size_kb INT,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
   FOREIGN KEY(material_id) REFERENCES materials(id) ON DELETE CASCADE) ENGINE=InnoDB`);
  await admin.query('REVOKE CREATE,ALTER,INDEX,REFERENCES ON '+db+".* FROM 'astha_test'@'127.0.0.1'");
  const [tables]=await admin.query('SHOW TABLES');
  for(const row of tables){const table=Object.values(row)[0];if(!/^[a-z_]+$/.test(table))throw Error('INVALID_TABLE');const permissions=['analytics_studies','analytics_snapshots','analytics_reviews','analytics_source_publications','asset_observations'].includes(table)?'SELECT,INSERT':table==='analytics_drafts'?'SELECT,INSERT,UPDATE':'SELECT,INSERT,UPDATE,DELETE';await admin.query('GRANT '+permissions+' ON '+db+'.'+table+" TO 'astha_test'@'127.0.0.1'");}
  const hash=await bcrypt.hash(password,10);
  const accounts=[];
  for(const {id,type,count=1} of fixtures){
   if(!/^(?:audit|tcc)-[a-z]+$/.test(id)||!['corporate','personal'].includes(type)||!Number.isInteger(count)||count<1||count>10)throw Error('INVALID_AUDIT_FIXTURE');
   await pool.execute('INSERT INTO organizations(id,name,workspace_type,setup_done) VALUES(?,?,?,1)',[id,'Espaço sintético de auditoria',type]);
   for(let index=0;index<count;index++){
    const role=count===1?'admin':['superadmin','admin','manager','operator','viewer'][Math.min(index,4)];
    const email=(count===1?id:id+'-'+(index+1))+'@example.invalid';
    const [created]=await pool.execute('INSERT INTO users(name,surname,email,password_hash,role,org_id,is_active,setup_done) VALUES(?,?,?,?,?,?,1,1)',['Auditoria '+(index+1),'Sintética',email,hash,role,id]);
    accounts.push({id:created.insertId,org_id:id,role,email,password});
   }
  }
  process.env.PORT=String(port);process.env.HOST='127.0.0.1';process.env.NODE_ENV='test';process.env.GEMINI_API_KEY='';process.env.ALLOWED_ORIGINS='http://127.0.0.1:'+port+',http://localhost:'+port;
  // startSandbox swaps the bootstrap pool; health must use that runtime pool too.
  require('../../api/database/connection').testConnection=async()=>{try{await pool.execute('SELECT 1');return true;}catch{return false;}};
  const {app}=require('../../api/server');
  server=await new Promise((resolve,reject)=>{const s=app.listen(port,'127.0.0.1',()=>resolve(s));s.on('error',reject);});
  stopAnalytics=require('../../api/routes/analytics').startProcessor();
  return {accounts,port,pool,admin,db,close};
 }catch(error){await close();throw error;}
}
async function main(){
 try{
  const {close}=await startAuditApp();
  console.log('AUDIT_APP_READY http://127.0.0.1:5183');
  const stop=()=>close().catch(()=>{process.exitCode=1;});
  process.on('SIGINT',stop);process.on('SIGTERM',stop);
  process.stdin.on('data',data=>{if(String(data).trim()==='stop')stop();});
  setTimeout(stop,60*60*1000).unref();
 }catch(error){console.error('AUDIT_APP_FAILED',error.code||error.message);process.exitCode=1;}
}
if(require.main===module)main();
module.exports={startAuditApp};
