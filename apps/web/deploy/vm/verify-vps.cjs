'use strict';
// Real smoke checks. Uses an isolated temporary tenant and removes only its own rows.
const crypto=require('node:crypto'),assert=require('node:assert/strict'),{createRequire}=require('node:module');
const load=createRequire('/opt/astha/releases/current/api/package.json');
async function main(){
  if(process.getuid?.()!==0)throw Error('ADMIN_REQUIRED');
  const db=await load('mysql2/promise').createConnection({socketPath:'/run/mysqld/mysqld.sock',user:'root',database:'astha_raven_prod',multipleStatements:false});
  const org='vps_smoke_'+crypto.randomBytes(10).toString('hex'),email=org+'@example.invalid',password=crypto.randomBytes(24).toString('hex');let userId;
  async function request(method,path,body,token){const response=await fetch('http://127.0.0.1:3000'+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(15000)});const text=await response.text();let data;try{data=JSON.parse(text);}catch(_){data=null;}return {status:response.status,data};}
  try{
    await db.execute('INSERT INTO organizations(id,name,workspace_type,setup_done) VALUES(?,?,?,1)',[org,'Temporary VPS validation','corporate']);
    const [created]=await db.execute('INSERT INTO users(name,email,password_hash,role,org_id,is_active) VALUES(?,?,?,?,?,1)',['Temporary VPS validation',email,await load('bcryptjs').hash(password,12),'admin',org]);userId=created.insertId;
    const login=await request('POST','/api/auth/login',{email,password});assert.equal(login.status,200);assert.ok(login.data.token);
    const token=login.data.token,me=await request('GET','/api/auth/me',null,token);assert.equal(me.status,200);
    assert.equal((await request('GET','/api/materials')).status,401);
    const materials=await request('GET','/api/materials',null,token);assert.equal(materials.status,200);assert.deepEqual(materials.data,[]);
    const endpoints=['/api/org/me','/api/org/units','/api/workspace/context','/api/account','/api/account/sessions','/api/warehouse/tabs','/api/warehouse/branches','/api/warehouse/insights','/api/eam/assets','/api/eam/work-orders','/api/eam/plans','/api/eam/reliability/summary','/api/procurement/suppliers','/api/procurement/planning/mrp','/api/components','/api/analytics/catalog','/api/analytics/studies'];
    for(const endpoint of endpoints){const r=await request('GET',endpoint,null,token);assert.equal(r.status,200,endpoint+':'+r.status);}
    const stock=await request('POST','/api/warehouse/tabs',{name:'Temporary migration verification'},token);assert.equal(stock.status,201);
    const material=await request('POST','/api/materials',{code:'VPS-SMOKE',description:'Temporary migration verification',quantity:1.25,min_qty:1,max_qty:10,unit_price:10,warehouse_id:stock.data.id},token);assert.equal(material.status,201);
    const entry=await request('POST','/api/movements/entry',{code:'VPS-SMOKE',quantity:.75,unit_price:12},token);assert.equal(entry.status,201);assert.equal(entry.data.new_stock,2);
    const exit=await request('POST','/api/movements/exit',{code:'VPS-SMOKE',quantity:.25},token);assert.equal(exit.status,201);assert.equal(exit.data.new_stock,1.75);
    const operation={id:crypto.randomUUID(),method:'POST',path:'/api/movements/entry',body:{code:'VPS-SMOKE',quantity:.125}};
    assert.equal((await request('POST','/api/sync/operations',operation,token)).status,200);
    const replay=await request('POST','/api/sync/operations',operation,token);assert.equal(replay.status,200);assert.equal(replay.data.replayed,true);
    const [[persisted]]=await db.execute('SELECT quantity FROM materials WHERE org_id=? AND code=?',[org,'VPS-SMOKE']);assert.equal(Number(persisted.quantity),1.875);
    const withdrawal={operation_id:crypto.randomUUID(),code:'VPS-SMOKE',quantity:.125,current_password:password};
    assert.equal((await request('POST','/api/movements/qr-exit',{...withdrawal,current_password:'incorrect'},token)).status,403);
    const qr=await request('POST','/api/movements/qr-exit',withdrawal,token);assert.equal(qr.status,200);assert.equal(qr.data.result.new_stock,1.75);
    const qrReplay=await request('POST','/api/movements/qr-exit',withdrawal,token);assert.equal(qrReplay.status,200);assert.equal(qrReplay.data.replayed,true);
    const [[qrStock]]=await db.execute('SELECT quantity FROM materials WHERE org_id=? AND code=?',[org,'VPS-SMOKE']);assert.equal(Number(qrStock.quantity),1.75);
    const [[valuation]]=await db.execute('SELECT unit_price FROM movement_valuation WHERE movement_id=?',[entry.data.id]);assert.equal(Number(valuation.unit_price),12);
    assert.equal((await request('GET','/api/personal/spaces',null,token)).status,404);
    const [[foreign]]=await db.execute('SELECT code FROM materials WHERE is_active=1 AND org_id<>? LIMIT 1',[org]);
    if(foreign){assert.equal((await request('GET','/api/materials/'+encodeURIComponent(foreign.code),null,token)).status,404);assert.equal((await request('POST','/api/sync/operations',{id:crypto.randomUUID(),method:'POST',path:'/api/movements/entry',body:{code:foreign.code,quantity:1}},token)).status,404);}
    await db.execute("UPDATE organizations SET workspace_type='personal' WHERE id=?",[org]);
    assert.equal((await request('GET','/api/materials',null,token)).status,404);
    assert.equal((await request('GET','/api/personal/spaces',null,token)).status,200);
    const room=await request('POST','/api/personal/spaces',{name:'Temporary personal room',width:4,depth:4,objects:[],tasks:[],belongings:[]},token);assert.equal(room.status,200);
    assert.equal((await request('GET','/api/personal/spaces/'+room.data.id,null,token)).status,200);
    const logout=await request('POST','/api/auth/logout',{},token);assert.equal(logout.status,200);assert.equal((await request('GET','/api/auth/me',null,token)).status,401);
    const env=load('dotenv').parse(await require('node:fs/promises').readFile('/etc/astha/runtime.env'));
    const runtime=await load('mysql2/promise').createConnection({host:env.DB_HOST,user:env.DB_USER,password:env.DB_PASSWORD,database:env.DB_NAME});
    try{await assert.rejects(runtime.query('CREATE TABLE __astha_ddl_guard(id INT)'),e=>['ER_TABLEACCESS_DENIED_ERROR','ER_DBACCESS_DENIED_ERROR'].includes(e.code));await assert.rejects(runtime.query('UPDATE analytics_snapshots SET id=id WHERE 1=0'),e=>e.code==='ER_TABLEACCESS_DENIED_ERROR');}finally{await runtime.end();}
    console.log(JSON.stringify({status:'VPS_SMOKE_PASSED',login:true,authenticatedGetEndpoints:endpoints.length,stockWrites:true,monetaryValue:true,qrWithdrawal:true,idempotentSync:true,personalSpace:true,sessionRevocation:true,tenantIsolation:true,personalBoundary:true,runtimeDDL:false,immutableEvidenceProtected:true}));
  }finally{
    if(userId){await db.beginTransaction();try{
      await db.execute('DELETE FROM mobile_sync_receipts WHERE org_id=? AND user_id=?',[org,userId]);
      await db.execute('DELETE FROM movement_valuation WHERE org_id=?',[org]);
      await db.execute('DELETE m FROM movements m JOIN materials t ON t.id=m.material_id WHERE t.org_id=?',[org]);await db.execute('DELETE FROM materials WHERE org_id=?',[org]);
      await db.execute('DELETE FROM warehouse_context WHERE org_id=?',[org]);await db.execute('DELETE FROM warehouses WHERE org_id=?',[org]);await db.execute('DELETE FROM warehouse_layout WHERE org_id=?',[org]);
      await db.execute('DELETE FROM sessions WHERE user_id=?',[userId]);await db.execute('DELETE FROM audit_log WHERE user_id=?',[userId]);await db.execute('DELETE FROM users WHERE id=? AND org_id=?',[userId,org]);await db.execute('DELETE FROM organizations WHERE id=? AND name=?',[org,'Temporary VPS validation']);await db.commit();
    }catch(e){await db.rollback();throw e;}}
    await db.end();
  }
}
if(require.main===module)main().catch(e=>{console.error('VPS_SMOKE_FAILED',e.code||'VALIDATION_FAILED');process.exitCode=1;});
