'use strict';
// Two encrypted SQLite backup containers, never replicas used by the application.
const fs=require('node:fs/promises'),path=require('node:path'),{spawn}=require('node:child_process');
const crypto=require('node:crypto'),{DatabaseSync}=require('node:sqlite');
const quote=name=>{if(!/^[a-zA-Z0-9_]{1,64}$/.test(name))throw Error('BACKUP_IDENTIFIER_INVALID');return '`'+name+'`';};
function windowsCommand(script,input){return new Promise((resolve,reject)=>{
  const exe=path.join(process.env.SystemRoot||'C:\\Windows','System32/WindowsPowerShell/v1.0/powershell.exe');
  const child=spawn(exe,['-NoProfile','-NonInteractive','-Command',script],{windowsHide:true,stdio:['pipe','pipe','ignore'],shell:false});let output='';
  const timer=setTimeout(()=>{child.kill();reject(Error('BACKUP_KEY_PROTECTION_TIMEOUT'));},15000);
  child.stdout.on('data',b=>{output+=b;if(output.length>4096)child.kill();});child.on('error',()=>{clearTimeout(timer);reject(Error('BACKUP_KEY_PROTECTION_FAILED'));});
  child.stdin.on('error',()=>reject(Error('BACKUP_KEY_PROTECTION_FAILED')));
  child.on('close',code=>{clearTimeout(timer);code===0?resolve(output.trim()):reject(Error('BACKUP_KEY_PROTECTION_FAILED'));});child.stdin.end(input);
});}
async function protectWindows(value,directory){
  await windowsCommand("$ErrorActionPreference='Stop'; $p=[Console]::In.ReadToEnd(); $acl=[IO.Directory]::GetAccessControl($p,[Security.AccessControl.AccessControlSections]::Access); $acl.SetAccessRuleProtection($true,$false); foreach($existing in @($acl.Access)){$acl.RemoveAccessRuleSpecific($existing)}; $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User; $rule=New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'); $acl.AddAccessRule($rule); [IO.Directory]::SetAccessControl($p,$acl)",directory);
  return windowsCommand("$ErrorActionPreference='Stop'; Add-Type -AssemblyName System.Security; $b=[Convert]::FromBase64String([Console]::In.ReadToEnd()); [Console]::Write([Convert]::ToBase64String([Security.Cryptography.ProtectedData]::Protect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))",value.toString('base64'));
}
function seal(key,value,aad){const nonce=crypto.randomBytes(12),cipher=crypto.createCipheriv('aes-256-gcm',key,nonce);cipher.setAAD(Buffer.from(aad));const bytes=Buffer.concat([cipher.update(JSON.stringify(value),'utf8'),cipher.final()]);return {nonce,tag:cipher.getAuthTag(),payload:bytes};}
function open(key,row,aad){const decipher=crypto.createDecipheriv('aes-256-gcm',key,row.nonce);decipher.setAAD(Buffer.from(aad));decipher.setAuthTag(row.tag);return JSON.parse(Buffer.concat([decipher.update(row.payload),decipher.final()]).toString('utf8'));}
async function backupPair(connection,directory,{key=crypto.randomBytes(32),protect=protectWindows}={}){
  await fs.mkdir(directory,{recursive:true,mode:0o700});
  const protectedKey=await protect(key,directory);
  await fs.writeFile(path.join(directory,'recovery-key.dpapi'),protectedKey,{mode:0o600,flag:'wx'});
  const targets=['backup-a.sqlite','backup-b.sqlite'].map(name=>({name,db:new DatabaseSync(path.join(directory,name))}));
  const manifest={createdAt:new Date().toISOString(),format:'astha-encrypted-mysql-snapshot-v1',scope:'Readable base tables and their CREATE TABLE definitions; views, routines and server configuration are not included.',timestampTimeZone:'+00:00',consistentSnapshot:true,tables:[],backups:[]};
  try{
    for(const t of targets){t.db.exec('PRAGMA journal_mode=DELETE; PRAGMA secure_delete=ON; CREATE TABLE records (table_name TEXT,row_number INTEGER,nonce BLOB NOT NULL,tag BLOB NOT NULL,payload BLOB NOT NULL,PRIMARY KEY(table_name,row_number)); CREATE TABLE definitions (table_name TEXT PRIMARY KEY,nonce BLOB NOT NULL,tag BLOB NOT NULL,payload BLOB NOT NULL); BEGIN');}
    await connection.query("SET SESSION time_zone='+00:00'");
    await connection.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');await connection.query('START TRANSACTION WITH CONSISTENT SNAPSHOT, READ ONLY');
    const [tables]=await connection.execute("SELECT TABLE_NAME,ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME");
    if(!tables.length)throw Error('BACKUP_EMPTY_SCHEMA');
    if(tables.some(t=>t.ENGINE!=='InnoDB'))throw Error('BACKUP_NON_TRANSACTIONAL_TABLE');
    for(const {TABLE_NAME:table} of tables){
      const [create]=await connection.query('SHOW CREATE TABLE '+quote(table));
      const [columns]=await connection.execute('SELECT COLUMN_NAME,DATA_TYPE,EXTRA FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? ORDER BY ORDINAL_POSITION',[table]);
      // Preserve MySQL calendar values and UTC instants regardless of mysql2's
      // dateStrings/timezone options on the caller's connection.
      const projection=columns.map(c=>['date','datetime','timestamp','time'].includes(c.DATA_TYPE)?'CAST('+quote(c.COLUMN_NAME)+' AS CHAR) AS '+quote(c.COLUMN_NAME):quote(c.COLUMN_NAME)).join(',');
      const [rows]=await connection.query('SELECT '+projection+' FROM '+quote(table));
      if(rows.length>100000||Buffer.byteLength(JSON.stringify(rows))>64*1024*1024)throw Error('BACKUP_TABLE_LIMIT');
      const digest=crypto.createHash('sha256');
      for(const target of targets){const row=seal(key,{sql:create[0]['Create Table'],columns},table+':ddl');target.db.prepare('INSERT INTO definitions VALUES (?,?,?,?)').run(table,row.nonce,row.tag,row.payload);}
      for(let i=0;i<rows.length;i++){
        digest.update(JSON.stringify(rows[i])+'\n');
        for(const target of targets){const row=seal(key,rows[i],table+':'+i);target.db.prepare('INSERT INTO records VALUES (?,?,?,?,?)').run(table,i,row.nonce,row.tag,row.payload);}
      }
      const expected=digest.digest('hex');
      for(const target of targets){const actual=crypto.createHash('sha256');for(const row of target.db.prepare('SELECT * FROM records WHERE table_name=? ORDER BY row_number').all(table))actual.update(JSON.stringify(open(key,row,table+':'+row.row_number))+'\n');if(actual.digest('hex')!==expected)throw Error('BACKUP_VERIFICATION_FAILED');}
      const [after]=await connection.query('SHOW CREATE TABLE '+quote(table));if(after[0]['Create Table']!==create[0]['Create Table'])throw Error('BACKUP_SCHEMA_CHANGED');
      manifest.tables.push({name:table,rows:rows.length,sha256:expected});
    }
    await connection.commit();
    for(const target of targets){target.db.exec('COMMIT');const check=target.db.prepare('PRAGMA integrity_check').get();if(Object.values(check)[0]!=='ok')throw Error('BACKUP_INTEGRITY_FAILED');target.db.close();target.closed=true;const bytes=await fs.readFile(path.join(directory,target.name));manifest.backups.push({file:target.name,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),verified:true});}
    manifest.hmac=crypto.createHmac('sha256',key).update(JSON.stringify(manifest)).digest('hex');
    await fs.writeFile(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2),{mode:0o600,flag:'wx'});
    return manifest;
  }catch(e){await connection.rollback().catch(()=>{});throw e;}finally{for(const target of targets)if(!target.closed)target.db.close();key.fill(0);}
}
async function verifyBackup(directory,{key,copy='backup-a.sqlite'}={}){
  if(!['backup-a.sqlite','backup-b.sqlite'].includes(copy))throw Error('BACKUP_COPY_INVALID');
  if(!key){const encrypted=await fs.readFile(path.join(directory,'recovery-key.dpapi'),'ascii');key=Buffer.from(await windowsCommand("$ErrorActionPreference='Stop'; Add-Type -AssemblyName System.Security; $b=[Convert]::FromBase64String([Console]::In.ReadToEnd()); [Console]::Write([Convert]::ToBase64String([Security.Cryptography.ProtectedData]::Unprotect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))",encrypted),'base64');}
  let db;
  try{
    const manifest=JSON.parse(await fs.readFile(path.join(directory,'manifest.json'),'utf8')),{hmac,...signed}=manifest;
    const expected=crypto.createHmac('sha256',key).update(JSON.stringify(signed)).digest();
    if(typeof hmac!=='string'||!/^[a-f0-9]{64}$/.test(hmac)||!crypto.timingSafeEqual(expected,Buffer.from(hmac,'hex')))throw Error('BACKUP_MANIFEST_AUTH_FAILED');
    const record=manifest.backups.find(b=>b.file===copy);
    if(!record||crypto.createHash('sha256').update(await fs.readFile(path.join(directory,copy))).digest('hex')!==record.sha256)throw Error('BACKUP_FILE_HASH_FAILED');
    db=new DatabaseSync(path.join(directory,copy),{readOnly:true});
    if(Object.values(db.prepare('PRAGMA integrity_check').get())[0]!=='ok')throw Error('BACKUP_INTEGRITY_FAILED');
    if(Number(db.prepare('SELECT COUNT(*) AS n FROM definitions').get().n)!==manifest.tables.length)throw Error('BACKUP_DEFINITION_COUNT_FAILED');
    const tables=[];
    for(const table of manifest.tables){
      quote(table.name);
      const definition=db.prepare('SELECT * FROM definitions WHERE table_name=?').get(table.name);
      if(!definition)throw Error('BACKUP_DEFINITION_MISSING');
      const data=open(key,definition,table.name+':ddl'),rows=db.prepare('SELECT * FROM records WHERE table_name=? ORDER BY row_number').all(table.name);
      if(rows.length!==table.rows)throw Error('BACKUP_ROW_COUNT_FAILED');
      const digest=crypto.createHash('sha256'),values=[];
      for(let i=0;i<rows.length;i++){if(Number(rows[i].row_number)!==i)throw Error('BACKUP_ROW_ORDER_FAILED');const value=open(key,rows[i],table.name+':'+i);digest.update(JSON.stringify(value)+'\n');values.push(value);}
      if(digest.digest('hex')!==table.sha256)throw Error('BACKUP_DATA_HASH_FAILED');
      tables.push({name:table.name,...data,rows:values});
    }
    return {manifest,tables};
  }finally{db?.close();key.fill(0);}
}
// This never replaces an existing database, including the source database.
async function restoreIntoNewDatabase(admin,target,verified,{productionTarget=false}={}){
  if(!/^astha_restore_[a-z0-9_]{1,40}$/.test(target)&&!(productionTarget&&target==='astha_raven_prod'))throw Error('RESTORE_NEW_SCHEMA_NAME_REQUIRED');
  const [existing]=await admin.execute('SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=?',[target]);
  if(existing.length)throw Error('RESTORE_TARGET_ALREADY_EXISTS');
  if(verified.manifest.timestampTimeZone==='+00:00')await admin.query("SET SESSION time_zone='+00:00'");
  await admin.query('CREATE DATABASE '+quote(target)+' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
  await admin.query('USE '+quote(target));
  try{
    await admin.query('SET FOREIGN_KEY_CHECKS=0');
    for(const table of verified.tables){if(!table.sql.startsWith('CREATE TABLE '+quote(table.name)+' ('))throw Error('RESTORE_DDL_REJECTED');await admin.query(table.sql);}
    for(const table of verified.tables){
      const columns=table.columns.filter(c=>!/(?:VIRTUAL|STORED) GENERATED/.test(String(c.EXTRA))).map(c=>c.COLUMN_NAME);
      const sql='INSERT INTO '+quote(table.name)+' ('+columns.map(quote).join(',')+') VALUES ('+columns.map(()=>'?').join(',')+')';
      for(const row of table.rows)await admin.execute(sql,columns.map(k=>{const v=row[k],type=table.columns.find(c=>c.COLUMN_NAME===k).DATA_TYPE;if(['datetime','timestamp'].includes(type)&&typeof v==='string'&&/^\d{4}-\d\d-\d\dT/.test(v))return v.replace('T',' ').replace('Z','');return ['bit','binary','varbinary','tinyblob','blob','mediumblob','longblob'].includes(type)&&v&&v.type==='Buffer'&&Array.isArray(v.data)?Buffer.from(v.data):v&&typeof v==='object'?JSON.stringify(v):v;}));
      const [[count]]=await admin.query('SELECT COUNT(*) AS n FROM '+quote(table.name));if(Number(count.n)!==table.rows.length)throw Error('RESTORE_COUNT_FAILED');
    }
    await admin.query('SET FOREIGN_KEY_CHECKS=1');
    const [keys]=await admin.execute('SELECT TABLE_NAME,CONSTRAINT_NAME,COLUMN_NAME,REFERENCED_TABLE_SCHEMA,REFERENCED_TABLE_NAME,REFERENCED_COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=? AND REFERENCED_TABLE_NAME IS NOT NULL ORDER BY TABLE_NAME,CONSTRAINT_NAME,ORDINAL_POSITION',[target]);
    if(keys.some(k=>k.REFERENCED_TABLE_SCHEMA!==target))throw Error('RESTORE_CROSS_SCHEMA_REFERENCE_REJECTED');
    const groups=new Map();for(const k of keys){const id=k.TABLE_NAME+':'+k.CONSTRAINT_NAME;if(!groups.has(id))groups.set(id,[]);groups.get(id).push(k);}
    for(const columns of groups.values()){const first=columns[0],join=columns.map(c=>'p.'+quote(c.REFERENCED_COLUMN_NAME)+'=c.'+quote(c.COLUMN_NAME)).join(' AND '),present=columns.map(c=>'c.'+quote(c.COLUMN_NAME)+' IS NOT NULL').join(' AND ');const [[orphans]]=await admin.query('SELECT COUNT(*) AS n FROM '+quote(first.TABLE_NAME)+' c LEFT JOIN '+quote(first.REFERENCED_TABLE_NAME)+' p ON '+join+' WHERE '+present+' AND p.'+quote(first.REFERENCED_COLUMN_NAME)+' IS NULL');if(Number(orphans.n))throw Error('RESTORE_FOREIGN_KEY_CHECK_FAILED');}
    return {target,tables:verified.tables.length,rows:verified.tables.reduce((n,t)=>n+t.rows.length,0)};
  }finally{await admin.query('SET FOREIGN_KEY_CHECKS=1');}
}
async function main(){
  const verify=process.argv.find(a=>a.startsWith('--verify='))?.slice(9);
  if(verify){const result=await verifyBackup(path.resolve(verify));console.log(JSON.stringify({verified:true,tables:result.tables.length,rows:result.tables.reduce((n,t)=>n+t.rows.length,0)}));return;}
  const profile=process.argv.find(a=>a.startsWith('--profile='))?.slice(10);
  if(profile!=='local')throw Error('USE_EXPLICIT_LOCAL_BACKUP_PROFILE');
  if(process.platform!=='win32')throw Error('WINDOWS_DPAPI_BACKUP_REQUIRED');
  const env=await require('../security/local-profile').load();
  const connection=await require('../node_modules/mysql2/promise').createConnection({host:env.DB_HOST,port:Number(env.DB_PORT||3306),database:env.DB_NAME,user:env.DB_USER,password:env.DB_PASSWORD,...require('../security/database-tls')(env),dateStrings:true,supportBigNumbers:true,bigNumberStrings:true,multipleStatements:false,flags:'-LOCAL_FILES'});
  const directory=path.join(process.env.LOCALAPPDATA,'ASTHA-RAVEN','backups',new Date().toISOString().replace(/[:.]/g,'-'));
  try{const result=await backupPair(connection,directory);console.log(JSON.stringify({profile,directory,tableCount:result.tables.length,rows:result.tables.reduce((n,t)=>n+t.rows,0),verifiedCopies:result.backups.length,format:result.format}));}finally{await connection.end();}
}
if(require.main===module)main().catch(e=>{console.error('BACKUP_FAILED',e.code||e.message);process.exitCode=1;});
module.exports={backupPair,open,verifyBackup,restoreIntoNewDatabase,protectWindows};
