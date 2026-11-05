'use strict';
const {startSandbox}=require('./analytics-sandbox');
const assert=require('node:assert/strict'),{randomUUID,randomBytes}=require('node:crypto');
async function main(){
  const sandbox=await startSandbox({allowRestoreTest:true});let server;
  try{
    const {pool,admin,db}=sandbox;
    await require('../../api/database/migrate_mobile_sync').migrateMobileSync(admin);
    await admin.query('GRANT SELECT,INSERT,UPDATE,DELETE ON '+db+".mobile_sync_receipts TO 'astha_test'@'127.0.0.1'");
    await admin.query('CREATE TABLE movement_valuation (movement_id INT PRIMARY KEY,warehouse_id INT NULL,unit_price DECIMAL(18,4),org_id VARCHAR(50)) ENGINE=InnoDB');
    await admin.query('GRANT SELECT,INSERT ON '+db+".movement_valuation TO 'astha_test'@'127.0.0.1'");
    const [cols]=await admin.execute("SHOW COLUMNS FROM organizations LIKE 'workspace_type'");
    if(!cols.length)await admin.query("ALTER TABLE organizations ADD COLUMN workspace_type VARCHAR(20) NOT NULL DEFAULT 'corporate'");
    const [setup]=await admin.execute("SHOW COLUMNS FROM organizations LIKE 'setup_done'");
    if(!setup.length)await admin.query('ALTER TABLE organizations ADD COLUMN setup_done TINYINT(1) NOT NULL DEFAULT 1');
    const tokens={},users={};
    for(const org of ['mobile-a','mobile-b']){
      await pool.execute('INSERT INTO organizations(id,name) VALUES(?,?)',[org,'Synthetic']);
      const [u]=await pool.execute('INSERT INTO users(name,email,password_hash,role,org_id,is_active) VALUES(?,?,?,?,?,1)',['Synthetic',org+'@example.invalid',randomBytes(32).toString('hex'),'admin',org]);users[org]=u.insertId;
      const {signToken,expiresAt}=require('../../api/security/tokens');const token=signToken({id:u.insertId,org_id:org});tokens[org]=token;
      await pool.execute('INSERT INTO sessions(user_id,token,expires_at) VALUES(?,?,?)',[u.insertId,token,expiresAt(token)]);
    }
    const [m]=await pool.execute('INSERT INTO materials(code,description,quantity,unit_price,org_id,is_active) VALUES(?,?,?,?,?,1)',['SYNC-A','Synthetic',5,10,'mobile-a']);
    const express=require('../../api/node_modules/express'),app=express();app.use(express.json());app.use('/api/sync',require('../../api/routes/mobile-sync'));app.use('/api/movements',require('../../api/routes/movements'));
    server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
    async function send(op,org='mobile-a'){const r=await fetch('http://127.0.0.1:'+server.address().port+'/api/sync/operations',{method:'POST',headers:{Authorization:'Bearer '+tokens[org],'content-type':'application/json'},body:JSON.stringify(op)});return{status:r.status,body:await r.json()};}
    const entry={id:randomUUID(),method:'POST',path:'/api/movements/entry',body:{code:'SYNC-A',quantity:.125}};
    const replies=await Promise.all([send(entry),send(entry),send(entry)]);assert.ok(replies.every(r=>r.status===200),JSON.stringify({replies,failure:sandbox.lastFailure()}));assert.equal(replies.filter(r=>!r.body.replayed).length,1);
    const [[stock]]=await pool.execute('SELECT quantity FROM materials WHERE id=?',[m.insertId]);assert.equal(Number(stock.quantity),5.125);
    const [[counts]]=await pool.execute('SELECT COUNT(*) AS total FROM movements WHERE material_id=?',[m.insertId]);assert.equal(Number(counts.total),1);
    assert.equal((await send({...entry,body:{code:'SYNC-A',quantity:2}})).status,409);
    assert.equal((await send(entry,'mobile-b')).status,404);
    console.log('PASS concurrent replay changes stock exactly once, binds identity and rejects reused payload IDs');
    // Minimal warehouse context for the exact nullable/numeric payload used by the Mobile form.
    await admin.query('CREATE TABLE warehouses(id INT AUTO_INCREMENT PRIMARY KEY,org_id VARCHAR(50),name VARCHAR(100)) ENGINE=InnoDB');
    await admin.query('CREATE TABLE warehouse_context(warehouse_id INT PRIMARY KEY,org_id VARCHAR(50),layout_id INT,org_unit_id INT NULL,parent_id INT NULL) ENGINE=InnoDB');
    await admin.query('CREATE TABLE warehouse_map_meta(layout_id INT,org_id VARCHAR(50),archived_at DATETIME NULL) ENGINE=InnoDB');
    for(const table of ['warehouses','warehouse_context','warehouse_map_meta'])await admin.query('GRANT SELECT,INSERT ON '+db+'.'+table+" TO 'astha_test'@'127.0.0.1'");
    const [w]=await pool.execute('INSERT INTO warehouses(org_id,name) VALUES(?,?)',['mobile-a','Mobile fixture']);
    await pool.execute('INSERT INTO warehouse_context(warehouse_id,org_id,layout_id) VALUES(?,?,?)',[w.insertId,'mobile-a',1]);
    const create={id:randomUUID(),method:'POST',path:'/api/materials',body:{code:'MOBILE-FORM',description:'Mobile form persistence',brand:null,model:null,sector:'Assembly',location:null,quantity:1.25,min_qty:0,max_qty:50,unit_price:12.34,unit:'UN',origin_country:null,barcode:null,machinery:null,notes:null,interchangeable:false,warehouse_id:w.insertId}};
    const createdMaterial=await send(create);assert.equal(createdMaterial.status,200,JSON.stringify(createdMaterial.body));assert.equal((await send(create)).body.replayed,true);
    const [[savedMaterial]]=await pool.execute('SELECT quantity,unit_price FROM materials WHERE org_id=? AND code=?',['mobile-a','MOBILE-FORM']);
    assert.equal(Number(savedMaterial.quantity),1.25);assert.equal(Number(savedMaterial.unit_price),12.34);
    const materialExit={id:randomUUID(),method:'POST',path:'/api/movements/exit',body:{code:'MOBILE-FORM',quantity:.25}};
    assert.equal((await send(materialExit)).status,200);assert.equal((await send(materialExit)).body.replayed,true);
    const [[savedExit]]=await pool.execute('SELECT quantity FROM materials WHERE org_id=? AND code=?',['mobile-a','MOBILE-FORM']);assert.equal(Number(savedExit.quantity),1);
    console.log('PASS Mobile form payload persists decimal quantity/price and withdrawal reaches MySQL exactly once');
    const exit={id:randomUUID(),method:'POST',path:'/api/movements/exit',body:{code:'SYNC-A',quantity:10}};
    assert.equal((await send(exit)).status,409);assert.equal((await send(exit)).status,409);
    const [[unchanged]]=await pool.execute('SELECT quantity FROM materials WHERE id=?',[m.insertId]);assert.equal(Number(unchanged.quantity),5.125);
    console.log('PASS conflicts are stable, visible and do not clamp stock');
    const transactional={...entry,id:randomUUID()};
    await admin.query('REVOKE INSERT ON '+db+".movement_valuation FROM 'astha_test'@'127.0.0.1'");
    assert.equal((await send(transactional)).status,503);
    const [[afterFailure]]=await pool.execute('SELECT quantity FROM materials WHERE id=?',[m.insertId]);assert.equal(Number(afterFailure.quantity),5.125);
    await admin.query('GRANT INSERT ON '+db+".movement_valuation TO 'astha_test'@'127.0.0.1'");
    assert.equal((await send(transactional)).status,200);
    console.log('PASS intermediate failure rolls back receipt and movement, permitting one safe retry');
    const [[beforeEdit]]=await pool.execute('SELECT * FROM materials WHERE id=?',[m.insertId]);
    const edit={id:randomUUID(),method:'PUT',path:'/api/materials/SYNC-A',expected_etag:require('../../api/services/mobile-sync').materialTag(beforeEdit),body:{description:'Updated synthetic'}};
    const edited=await send(edit);assert.equal(edited.status,200);assert.equal((await send(edit)).status,200);
    assert.equal((await send({...edit,id:randomUUID()})).status,409);
    assert.equal((await send({...edit,id:randomUUID()},'mobile-b')).status,404);
    const removal={id:randomUUID(),method:'DELETE',path:'/api/materials/SYNC-A',expected_etag:edited.body.result.sync_etag,body:{}};
    assert.equal((await send(removal)).status,200);assert.equal((await send(removal)).status,200);
    const [[removed]]=await pool.execute('SELECT is_active FROM materials WHERE id=?',[m.insertId]);assert.equal(Number(removed.is_active),0);
    console.log('PASS material updates/deletions replay safely and reject stale or foreign versions');
    await pool.execute("UPDATE users SET role='viewer' WHERE id=?",[users['mobile-a']]);assert.equal((await send({...entry,id:randomUUID()})).status,403);
    assert.equal((await send(entry)).status,403);
    await pool.execute("UPDATE users SET role='admin' WHERE id=?",[users['mobile-a']]);
    await pool.execute("UPDATE organizations SET workspace_type='personal' WHERE id='mobile-a'");assert.equal((await send(entry)).status,404);
    console.log('PASS live role and workspace checks precede even successful cached receipts');
    for(const [column,definition] of [['org_id','VARCHAR(50)'],['blueprint_data','LONGTEXT']]){
      const [found]=await admin.execute("SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='warehouse_layout' AND COLUMN_NAME=?",[column]);
      if(!found.length)await admin.query('ALTER TABLE warehouse_layout ADD COLUMN '+column+' '+definition);
    }
    const personalOp={id:randomUUID(),method:'POST',path:'/api/personal/spaces',body:{name:'Synthetic room',width:6,depth:5,objects:[],tasks:[]}};
    const personalFirst=await send(personalOp),personalReplay=await send(personalOp);
    assert.equal(personalFirst.status,200);assert.equal(personalReplay.status,200);assert.equal(personalFirst.body.result.id,personalReplay.body.result.id);
    const personalSpace=personalFirst.body.result;
    const changedSpace={id:randomUUID(),method:'PUT',path:'/api/personal/spaces/'+personalSpace.id,body:{...personalSpace,name:'Updated room'}};
    assert.equal((await send(changedSpace)).status,200);
    assert.equal((await send({...changedSpace,id:randomUUID()})).status,409);
    await pool.execute("UPDATE organizations SET workspace_type='personal' WHERE id='mobile-b'");
    assert.equal((await send({...changedSpace,id:randomUUID()},'mobile-b')).status,404);
    const [[spaces]]=await pool.execute('SELECT COUNT(*) AS n FROM warehouse_layout WHERE org_id=?',['mobile-a']);assert.equal(Number(spaces.n),1);
    console.log('PASS personal spaces reuse the domain transaction, persist exactly once and reject stale/foreign edits');
    // QR withdrawals reauthenticate online and never persist the password.
    await pool.execute("UPDATE organizations SET workspace_type='corporate' WHERE id='mobile-a'");
    await pool.execute('UPDATE materials SET is_active=1 WHERE id=?',[m.insertId]);
    const password=randomBytes(24).toString('base64');
    await pool.execute("UPDATE users SET password_hash=?,provider='local' WHERE id=?",[await require('../../api/node_modules/bcryptjs').hash(password,4),users['mobile-a']]);
    async function qr(body,org='mobile-a',authenticated=true){
      const r=await fetch('http://127.0.0.1:'+server.address().port+'/api/movements/qr-exit',{method:'POST',headers:{...(authenticated?{Authorization:'Bearer '+tokens[org]}:{}),'content-type':'application/json'},body:JSON.stringify(body)});
      return {status:r.status,body:await r.json()};
    }
    const withdrawal={operation_id:randomUUID(),code:'SYNC-A',quantity:.25,current_password:password};
    assert.equal((await qr(withdrawal,'mobile-a',false)).status,401);
    assert.equal((await qr({...withdrawal,current_password:''})).status,400);
    assert.equal((await qr({...withdrawal,current_password:'incorrect'})).status,403);
    assert.equal((await qr(withdrawal,'mobile-b')).status,403);
    await pool.execute("UPDATE users SET role='viewer' WHERE id=?",[users['mobile-a']]);assert.equal((await qr(withdrawal)).status,403);
    await pool.execute("UPDATE users SET role='admin' WHERE id=?",[users['mobile-a']]);
    assert.equal((await qr({...withdrawal,operation_id:randomUUID(),code:'FOREIGN-MISSING'})).status,404);
    const first=await qr(withdrawal),repeat=await qr(withdrawal);
    assert.equal(first.status,200,JSON.stringify(first));assert.equal(repeat.status,200);assert.equal(repeat.body.replayed,true);
    assert.equal((await qr({...withdrawal,quantity:.5})).status,409);
    const [[qrStock]]=await pool.execute('SELECT quantity FROM materials WHERE id=?',[m.insertId]);assert.equal(Number(qrStock.quantity),5);
    const [receipts]=await pool.execute('SELECT * FROM mobile_sync_receipts WHERE operation_id=?',[withdrawal.operation_id]);
    assert.ok(!JSON.stringify(receipts).includes(password));assert.ok(!JSON.stringify(receipts).includes('current_password'));
    await pool.execute('UPDATE materials SET quantity=5.25 WHERE id=?',[m.insertId]);
    console.log('PASS QR withdrawal requires a valid local password/role, isolates tenants, debits once and excludes credentials from receipts');
    const backups=require('../../api/tools/backup-snapshots.cjs'),path=require('node:path'),fs=require('node:fs/promises');
    const key=randomBytes(32),directory=path.join(sandbox.workspace,'backup');
    await admin.query('CREATE TABLE backup_time_probe (id INT PRIMARY KEY, instant TIMESTAMP(6) NULL, calendar DATETIME(6), day DATE, elapsed TIME(6), payload JSON, bytes VARBINARY(8)) ENGINE=InnoDB');
    await admin.query("SET SESSION time_zone='-03:00'");
    await admin.execute('INSERT INTO backup_time_probe VALUES (?,?,?,?,?,?,?)',[1,'2026-10-21 10:12:13.123456','2026-10-21 10:12:13.654321','2026-10-21','-30:01:02.123456',JSON.stringify({type:'Buffer',data:[42]}),Buffer.from([0,255,128])]);
    await admin.execute('INSERT INTO backup_time_probe (id) VALUES (?)',[2]);
    await backups.backupPair(admin,directory,{key:Buffer.from(key),protect:async()=> 'synthetic-test-key-wrapper'});
    const verified=await backups.verifyBackup(directory,{key:Buffer.from(key)});
    const secondCopy=await backups.verifyBackup(directory,{key:Buffer.from(key),copy:'backup-b.sqlite'});assert.equal(secondCopy.tables.length,verified.tables.length);
    assert.equal(verified.manifest.timestampTimeZone,'+00:00');
    assert.equal(verified.tables.find(t=>t.name==='backup_time_probe').rows[0].instant,'2026-10-21 13:12:13.123456');
    await admin.query("SET SESSION time_zone='+09:00'");
    const restored=await backups.restoreIntoNewDatabase(admin,'astha_restore_test',verified);
    assert.ok(restored.tables>30);assert.ok(restored.rows>2);
    const [[restoredStock]]=await admin.execute('SELECT quantity FROM materials WHERE code=?',['SYNC-A']);assert.equal(Number(restoredStock.quantity),5.25);
    const [probe]=await admin.query('SELECT id,CAST(instant AS CHAR) AS instant,CAST(calendar AS CHAR) AS calendar,CAST(day AS CHAR) AS day,CAST(elapsed AS CHAR) AS elapsed,payload,bytes FROM backup_time_probe ORDER BY id');
    assert.equal(probe[0].instant,'2026-10-21 13:12:13.123456');assert.equal(probe[0].calendar,'2026-10-21 10:12:13.654321');assert.equal(probe[0].day,'2026-10-21');assert.equal(probe[0].elapsed,'-30:01:02.123456');
    assert.deepEqual(probe[0].payload,{type:'Buffer',data:[42]});assert.deepEqual(probe[0].bytes,Buffer.from([0,255,128]));assert.equal(probe[1].instant,null);
    await assert.rejects(backups.restoreIntoNewDatabase(admin,'astha_restore_test',verified),/TARGET_ALREADY_EXISTS/);
    const manifestPath=path.join(directory,'manifest.json'),manifest=JSON.parse(await fs.readFile(manifestPath,'utf8'));manifest.tables.pop();await fs.writeFile(manifestPath,JSON.stringify(manifest));
    await assert.rejects(backups.verifyBackup(directory,{key:Buffer.from(key)}),/MANIFEST_AUTH_FAILED/);key.fill(0);
    console.log('PASS both encrypted backup copies verify; restore preserves UTC/microseconds/calendar/binary/JSON values and refuses existing schemas/tampered manifests');
  }finally{if(server){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}await sandbox.close();}
}
main().catch(e=>{console.error('MOBILE_SYNC_TEST_FAILED',e.stack);process.exitCode=1;});
