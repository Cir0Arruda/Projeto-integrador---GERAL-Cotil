'use strict';
// Four companies and twenty authenticated actors against real, disposable MySQL.
const assert=require('node:assert/strict');
const {randomBytes,randomUUID}=require('node:crypto');
const {startSandbox}=require('./analytics-sandbox');
async function main(){
 const sandbox=await startSandbox();let server;
 try{
  const {admin,pool}=sandbox;
  await require('../../api/database/migrate_material_code_scope').migrateMaterialCodeScope(admin);
  await admin.query('ALTER TABLE organizations ADD COLUMN workspace_type VARCHAR(20) NOT NULL DEFAULT \'corporate\'');
  await admin.query('ALTER TABLE organizations ADD COLUMN setup_done TINYINT(1) NOT NULL DEFAULT 1');
  await admin.query('CREATE TABLE org_access_groups(id INT AUTO_INCREMENT PRIMARY KEY,org_id VARCHAR(50),permissions JSON) ENGINE=InnoDB');
  await admin.query('CREATE TABLE org_access_group_members(org_id VARCHAR(50),group_id INT,user_id INT) ENGINE=InnoDB');
  for(const table of ['org_access_groups','org_access_group_members'])await admin.query('GRANT SELECT ON '+sandbox.db+'.'+table+" TO 'astha_test'@'127.0.0.1'");
  const roles=['admin','manager','operator','operator','viewer'],companies=[];
  const {signToken,expiresAt}=require('../../api/security/tokens');
  for(let company=0;company<4;company++){
   const org='eam_company_'+company+'_'+randomBytes(6).toString('hex'),actors=[];
   await admin.execute('INSERT INTO organizations(id,name,workspace_type) VALUES(?,?,?)',[org,'Synthetic EAM company '+company,'corporate']);
   for(let actor=0;actor<roles.length;actor++){
    const email=org+'_'+actor+'@example.invalid';
    const [user]=await admin.execute('INSERT INTO users(name,email,password_hash,role,org_id,is_active) VALUES(?,?,?,?,?,1)',['Synthetic EAM '+actor,email,'not-a-valid-login-hash',roles[actor],org]);
    const token=signToken({id:user.insertId,email,role:roles[actor],org_id:org});
    await admin.execute('INSERT INTO sessions(user_id,token,expires_at) VALUES(?,?,?)',[user.insertId,token,expiresAt(token)]);
    actors.push({id:user.insertId,token,role:roles[actor]});
   }
   companies.push({org,actors});
  }
  const express=require('../../api/node_modules/express'),app=express();app.use(express.json());
  app.use('/eam',...require('../../api/middleware/workspaceMode').corporateOnly,...require('../../api/middleware/groupAccess')('eam'),require('../../api/routes/eam'));
  app.use('/procurement',...require('../../api/middleware/workspaceMode').corporateOnly,...require('../../api/middleware/groupAccess')('eam'),require('../../api/routes/procurement'));
  server=await new Promise(resolve=>{const item=app.listen(0,'127.0.0.1',()=>resolve(item));});
  const base='http://127.0.0.1:'+server.address().port;
  async function request(company,actor,endpoint,method='GET',body,expected=200){
   const response=await fetch(base+endpoint,{method,headers:{authorization:'Bearer '+companies[company].actors[actor].token,'content-type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});
   const data=await response.json();
   if(expected!==null)assert.equal(response.status,expected,endpoint+': '+JSON.stringify({status:response.status,data,db:sandbox.lastFailure()}));
   return {status:response.status,data};
  }
  const defects=[];
  const seed=await request(0,0,'/eam/assets','POST',{asset_code:'ASSIGN-SEED',name:'Assignment boundary fixture'},201);
  const assignment=await request(0,0,'/eam/work-orders','POST',{asset_id:seed.data.id,title:'Cross-tenant assignment must be refused',assigned_to:companies[1].actors[2].id},null);
  if(assignment.status!==404)defects.push('cross-tenant assignee accepted:'+assignment.status);
  const disabled=companies[0].actors[3];await admin.execute('UPDATE users SET is_active=0 WHERE id=?',[disabled.id]);
  const inactive=await request(0,0,'/eam/work-orders','POST',{asset_id:seed.data.id,title:'Inactive assignment must be refused',assigned_to:disabled.id},null);
  if(inactive.status!==404)defects.push('inactive assignee accepted:'+inactive.status);
  await admin.execute('UPDATE users SET is_active=1 WHERE id=?',[disabled.id]);
  // A barrier in the old non-transactional cycle read makes its race deterministic.
  const execute=pool.execute.bind(pool);let arrivals=0,release;const gate=new Promise(resolve=>{release=resolve;});
  pool.execute=async(sql,params)=>{
   const result=await execute(sql,params);
   if(sql.startsWith('WITH RECURSIVE ancestors AS')){arrivals++;if(arrivals===2)release();await Promise.race([gate,new Promise(resolve=>setTimeout(resolve,1000))]);}
   return result;
  };
  const a=(await request(0,0,'/eam/assets','POST',{asset_code:'RACE-A',name:'Concurrent parent A'},201)).data;
  const b=(await request(0,0,'/eam/assets','POST',{asset_code:'RACE-B',name:'Concurrent parent B'},201)).data;
  const race=await Promise.all([request(0,1,`/eam/assets/${a.id}/parent`,'PATCH',{parent_asset_id:b.id},null),request(0,2,`/eam/assets/${b.id}/parent`,'PATCH',{parent_asset_id:a.id},null)]);
  pool.execute=execute;
  if(race.map(item=>item.status).sort().join(',')!=='200,409')defects.push('concurrent hierarchy cycle:'+race.map(item=>item.status).join(','));
  // Repair only this disposable fixture so later scenarios can run even before a fix.
  await admin.execute('UPDATE assets SET parent_asset_id=NULL WHERE id IN (?,?)',[a.id,b.id]);
  console.log(JSON.stringify({gate:'EAM_REGRESSION_FINDINGS',defects}));
  assert.deepEqual(defects,[],'Confirmed EAM regressions');
  const mixed=await Promise.all([request(0,1,`/eam/assets/${a.id}`,'PATCH',{name:'Concurrent parent A',status:'active',criticality:'medium',parent_asset_id:b.id},null),request(0,2,`/eam/assets/${b.id}/parent`,'PATCH',{parent_asset_id:a.id},null)]);
  assert.deepEqual(mixed.map(item=>item.status).sort(),[200,409]);
  const f1=(await request(0,0,'/eam/functional-locations','POST',{location_code:'LOCATION-A',name:'Location A'},201)).data;
  const f2=(await request(0,0,'/eam/functional-locations','POST',{location_code:'LOCATION-B',name:'Location B'},201)).data;
  const locations=await Promise.all([request(0,0,`/eam/functional-locations/${f1.id}`,'PATCH',{parent_location_id:f2.id},null),request(0,1,`/eam/functional-locations/${f2.id}`,'PATCH',{parent_location_id:f1.id},null)]);
  assert.deepEqual(locations.map(item=>item.status).sort(),[200,409]);
  const getConnection=pool.getConnection.bind(pool);
  pool.getConnection=async()=>{
   const c=await getConnection();return {execute:async(sql,args)=>{if(sql.startsWith('INSERT INTO work_order_audit'))throw Error('SYNTHETIC_AUDIT_FAILURE');return c.execute(sql,args);},beginTransaction:()=>c.beginTransaction(),commit:()=>c.commit(),rollback:()=>c.rollback(),release:()=>c.release(),destroy:()=>c.destroy()};
  };
  try{await request(0,0,'/eam/work-orders','POST',{asset_id:seed.data.id,title:'Atomic creation rollback fixture'},500);}finally{pool.getConnection=getConnection;}
  const [[rolledBack]]=await admin.execute('SELECT COUNT(*) AS n FROM maintenance_work_orders WHERE org_id=? AND title=?',[companies[0].org,'Atomic creation rollback fixture']);assert.equal(Number(rolledBack.n),0);
  const raceOrder=(await request(0,0,'/eam/work-orders','POST',{asset_id:seed.data.id,title:'Task vs completion fixture'},201)).data;
  await request(0,0,`/eam/work-orders/${raceOrder.id}/release`,'POST',{});
  await request(0,2,`/eam/work-orders/${raceOrder.id}/status`,'PATCH',{status:'in_progress'});
  let taskRead,unblockTask;const taskReadGate=new Promise(resolve=>{taskRead=resolve;}),taskBlock=new Promise(resolve=>{unblockTask=resolve;});
  pool.execute=async(sql,params)=>{const result=await execute(sql,params);if(sql.startsWith('SELECT id,status FROM maintenance_work_orders')&&params[0]===raceOrder.id){taskRead();await taskBlock;}return result;};
  const creation=request(0,2,`/eam/work-orders/${raceOrder.id}/tasks`,'POST',{title:'Must not appear after closure'},null);
  await Promise.race([taskReadGate,new Promise(resolve=>setTimeout(resolve,100))]);
  let completion;
  try{completion=await request(0,2,`/eam/work-orders/${raceOrder.id}/status`,'PATCH',{status:'completed'},null);}finally{unblockTask();pool.execute=execute;}
  const taskCreated=await creation;
  assert.ok((taskCreated.status===201&&completion.status===409)||(taskCreated.status===409&&completion.status===200),'Task creation and order completion cannot both commit');
  const laborOrder=(await request(0,0,'/eam/work-orders','POST',{asset_id:seed.data.id,title:'Labor assignment and closure fixture'},201)).data;
  await request(0,0,`/eam/work-orders/${laborOrder.id}/release`,'POST',{});
  await request(0,2,`/eam/work-orders/${laborOrder.id}/status`,'PATCH',{status:'in_progress'});
  const foreignLabor=await request(0,2,`/eam/work-orders/${laborOrder.id}/labor`,'POST',{hours:1,hourly_rate:10,user_id:companies[1].actors[2].id},null);
  console.log(JSON.stringify({gate:'LABOR_ASSIGNMENT_BOUNDARY',status:foreignLabor.status}));
  assert.equal(foreignLabor.status,404,'Labor assignee must belong to the work order tenant');
  await admin.execute('UPDATE users SET is_active=0 WHERE id=?',[companies[0].actors[3].id]);
  await request(0,2,`/eam/work-orders/${laborOrder.id}/labor`,'POST',{hours:1,hourly_rate:10,user_id:companies[0].actors[3].id},404);
  await admin.execute('UPDATE users SET is_active=1 WHERE id=?',[companies[0].actors[3].id]);
  await request(0,2,`/eam/work-orders/${laborOrder.id}/labor`,'POST',{hours:1,hourly_rate:10,user_id:'invalid'},400);
  let laborLocked,releaseLabor;const laborLockGate=new Promise(resolve=>{laborLocked=resolve;}),laborHold=new Promise(resolve=>{releaseLabor=resolve;});
  pool.getConnection=async()=>{
   const c=await getConnection();return {execute:async(sql,args)=>{const result=await c.execute(sql,args);if(sql.startsWith('SELECT id,status FROM maintenance_work_orders')&&args[0]===laborOrder.id){laborLocked();await laborHold;}return result;},beginTransaction:()=>c.beginTransaction(),commit:()=>c.commit(),rollback:()=>c.rollback(),release:()=>c.release(),destroy:()=>c.destroy()};
  };
  try{
   const pointing=request(0,2,`/eam/work-orders/${laborOrder.id}/labor`,'POST',{hours:1,hourly_rate:10},201);
   await Promise.race([laborLockGate,new Promise((_,reject)=>setTimeout(()=>reject(Error('LABOR_LOCK_NOT_OBSERVED')),2000))]);
   let closed=false;const closure=request(0,2,`/eam/work-orders/${laborOrder.id}/status`,'PATCH',{status:'completed'}).then(value=>{closed=true;return value;});
   await new Promise(resolve=>setTimeout(resolve,100));assert.equal(closed,false,'Completion waits for the labor transaction');
   releaseLabor();await Promise.all([pointing,closure]);
  }finally{releaseLabor();pool.getConnection=getConnection;}
  const [raceMat]=await admin.execute('INSERT INTO materials(org_id,code,description,quantity) VALUES(?,?,?,?)',[companies[0].org,'REQ-RACE','Requisition fixture',1]);
  const [raceReq]=await admin.execute("INSERT INTO purchase_requisitions(org_id,material_id,requested_quantity,status,reason) VALUES(?,?,?,'requested',?)",[companies[0].org,raceMat.insertId,1,'Requisition status race fixture']);
  let reqReads=0,unblockReq;const reqGate=new Promise(resolve=>{unblockReq=resolve;});
  pool.execute=async(sql,params)=>{const result=await execute(sql,params);if(sql.startsWith('SELECT status FROM purchase_requisitions')&&params[0]===raceReq.insertId){if(++reqReads===2)unblockReq();await Promise.race([reqGate,new Promise(resolve=>setTimeout(resolve,500))]);}return result;};
  let transitions;
  try{transitions=await Promise.all([request(0,0,`/eam/purchase-requisitions/${raceReq.insertId}/status`,'PATCH',{status:'approved'},null),request(0,1,`/eam/purchase-requisitions/${raceReq.insertId}/status`,'PATCH',{status:'cancelled',reason:'Race fixture'},null)]);}finally{pool.execute=execute;unblockReq();}
  assert.deepEqual(transitions.map(item=>item.status).sort(),[200,409],'Only one conflicting requisition transition may commit');
  for(let company=0;company<4;company++){
   const mother=(await request(company,0,'/eam/assets','POST',{asset_code:'MACHINE-MOTHER',name:'Mother compressor'},201)).data;
   const child=(await request(company,2,'/eam/assets','POST',{asset_code:'MACHINE-MOTOR',name:'Drive motor',parent_asset_id:mother.id},201)).data;
   const grandchild=(await request(company,2,'/eam/assets','POST',{asset_code:'MACHINE-BEARING',name:'Bearing assembly',parent_asset_id:child.id},201)).data;
   await request(company,4,'/eam/assets','POST',{asset_code:'VIEWER-DENIED',name:'Denied'},403);
   await request(company,2,`/eam/assets/${mother.id}/parent`,'PATCH',{parent_asset_id:grandchild.id},409);
   const [material]=await admin.execute('INSERT INTO materials(org_id,code,description,quantity,unit,unit_price,is_active) VALUES(?,?,?,?,?,?,1)',[companies[company].org,'BEARING-6205','Synthetic bearing',20,'UN',25]);
   await request(company,2,`/eam/assets/${child.id}/spares`,'POST',{material_id:material.insertId,quantity:1,minimum_quantity:1,maximum_quantity:4},201);
   const order=(await request(company,2,'/eam/work-orders','POST',{asset_id:child.id,title:'Replace bearing',type:'corrective',assigned_to:companies[company].actors[3].id},201)).data;
   const listed=(await request(company,4,'/eam/work-orders')).data.find(item=>item.id===order.id);assert.equal(listed.assigned_to_name,'Synthetic EAM 3');
   await request(company,2,`/eam/work-orders/${order.id}/status`,'PATCH',{status:'in_progress'},409);
   await request(company,2,`/eam/work-orders/${order.id}/release`,'POST',{},403);
   await request(company,1,`/eam/work-orders/${order.id}/release`,'POST',{});
   await request(company,3,`/eam/work-orders/${order.id}/status`,'PATCH',{status:'in_progress'});
   const task=(await request(company,2,`/eam/work-orders/${order.id}/tasks`,'POST',{title:'Isolate, replace and inspect'},201)).data;
   await request(company,2,`/eam/work-orders/${order.id}/status`,'PATCH',{status:'completed'},409);
   await request(company,2,`/eam/work-orders/${order.id}/material-requests`,'POST',{material_id:material.insertId,quantity:2},201);
   await request(company,2,`/eam/work-orders/${order.id}/material-requests/${material.insertId}`,'PATCH',{status:'approved',approved_quantity:2},403);
   await request(company,1,`/eam/work-orders/${order.id}/material-requests/${material.insertId}`,'PATCH',{status:'approved',approved_quantity:2});
   await request(company,3,`/eam/work-orders/${order.id}/materials`,'POST',{material_id:material.insertId,quantity:1},201);
   const labor=(await request(company,3,`/eam/work-orders/${order.id}/labor`,'POST',{hours:1.5,hourly_rate:20,user_id:companies[company].actors[2].id},201)).data;assert.equal(labor.labor_cost,30);
   await request(company,3,`/eam/work-orders/${order.id}/downtime`,'POST',{started_at:'2026-09-01T03:00:00Z',ended_at:'2026-09-01T04:00:00Z',failure_symptom:'Synthetic bearing failure'},201);
   const empty=(await request(company,4,`/eam/reliability/assets/${mother.id}?from=2026-09-01T00:00:00Z&to=2026-09-02T00:00:00Z`)).data;assert.equal(empty.mtbf_hours,null);assert.equal(empty.mttr_hours,null);
   for(const observed of [{kind:'operation',started_at:'2026-09-01T00:00:00Z',ended_at:'2026-09-01T03:00:00Z'},{kind:'failure',started_at:'2026-09-01T03:00:00Z',ended_at:'2026-09-01T04:00:00Z',repair_started_at:'2026-09-01T03:15:00Z',repair_ended_at:'2026-09-01T03:45:00Z'},{kind:'operation',started_at:'2026-09-01T04:00:00Z',ended_at:'2026-09-02T00:00:00Z'}])await request(company,2,`/eam/assets/${child.id}/observations`,'POST',{...observed,request_key:randomUUID(),source:'Synthetic TCC workflow',notes:'Disposable test record',confirmed:true},201);
   const qualified=(await request(company,4,`/eam/reliability/assets/${child.id}?from=2026-09-01T00:00:00Z&to=2026-09-02T00:00:00Z`)).data;assert.equal(qualified.mttr_hours,.5);assert.equal(qualified.mtbf_hours,23);assert.equal(qualified.downtime_hours,1);
   await request(company,2,`/eam/work-orders/${order.id}/tasks/${task.id}`,'PATCH',{is_completed:true});
   await request(company,3,`/eam/work-orders/${order.id}/status`,'PATCH',{status:'completed'});
   await request(company,2,`/eam/work-orders/${order.id}/financial-close`,'POST',{},403);
   await request(company,1,`/eam/work-orders/${order.id}/financial-close`,'POST',{});
   await request(company,2,`/eam/work-orders/${order.id}/materials/${material.insertId}/return`,'POST',{quantity:1},409);
   const [[stock]]=await admin.execute('SELECT quantity FROM materials WHERE id=?',[material.insertId]);assert.equal(Number(stock.quantity),19);
   const [audits]=await admin.execute('SELECT actor_id,action FROM work_order_audit WHERE work_order_id=?',[order.id]);
   assert(audits.some(item=>item.actor_id===companies[company].actors[1].id&&item.action==='released'));
   assert(audits.some(item=>item.actor_id===companies[company].actors[3].id&&item.action==='status_changed'));
   const other=(company+1)%4;
   await request(other,0,`/eam/assets/${mother.id}/component-rollup`,'GET',undefined,404);
   await request(other,0,`/eam/work-orders/${order.id}/release`,'POST',{},404);
   const due=new Date(Date.now()-86400000).toISOString().slice(0,10);
   const plan=(await request(company,1,'/eam/plans','POST',{asset_id:mother.id,title:'Mother preventive inspection',interval_days:30,next_due_at:due,tasks:['Inspect seals']},201)).data;
   const runs=await Promise.all([request(company,0,'/eam/plans/run-due','POST',{}),request(company,1,'/eam/plans/run-due','POST',{})]);
   assert.equal(runs.reduce((total,item)=>total+item.data.count,0),1);
   const overview=await request(company,4,`/eam/plans/overview?month=${due.slice(0,7)}&asset_id=${mother.id}`);
   assert.equal(Number(overview.data.stats.find(item=>item.plan_id===plan.id).generated_count),1);
   const [group]=await admin.execute('INSERT INTO org_access_groups(org_id,permissions) VALUES(?,?)',[companies[company].org,JSON.stringify({eam:{read:true,write:false}})]);
   await admin.execute('INSERT INTO org_access_group_members(org_id,group_id,user_id) VALUES(?,?,?)',[companies[company].org,group.insertId,companies[company].actors[2].id]);
   await request(company,2,'/eam/assets');
   await request(company,2,'/eam/assets','POST',{asset_code:'GROUP-DENIED',name:'Denied by group'},403);
   await admin.execute('UPDATE users SET is_active=0 WHERE id=?',[companies[company].actors[3].id]);
   await request(company,3,'/eam/assets','GET',undefined,401);
   console.log(JSON.stringify({gate:'EAM_COMPANY_WORKFLOW_PASSED',company,actors:5,parentDepth:3,stock:19,preventives:1,laborCost:labor.labor_cost,mttrHours:qualified.mttr_hours,mtbfHours:qualified.mtbf_hours,downtimeHours:qualified.downtime_hours}));
  }
  console.log('EAM_MULTI_TENANT_WORKFLOW_PASSED');
 }finally{if(server){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}await sandbox.close();}
}
main().catch(error=>{console.error('EAM_MULTI_TENANT_WORKFLOW_FAILED',error.code||'VALIDATION_FAILED',error.code==='ERR_ASSERTION'?error.message:'');process.exitCode=1;});
