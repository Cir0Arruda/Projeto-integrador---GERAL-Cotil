'use strict';
const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const express=require('../../api/node_modules/express');
let mode='unavailable',destroyed=0,released=0;
const dbFailure=Object.assign(new Error('SYNTHETIC_PRIVATE_DB_DETAILS'),{code:'ECONNREFUSED'});
const connection={
  beginTransaction:async()=>{throw dbFailure;},
  rollback:async()=>{throw dbFailure;},
  destroy:()=>destroyed++,release:()=>released++
};
require.cache[require.resolve('../../api/database/connection')]={exports:{pool:{
  getConnection:async()=>{if(mode==='unavailable')throw dbFailure;return connection;}
}}};
require.cache[require.resolve('../../api/middleware/auth')]={exports:(req,res,next)=>{
  req.user={id:1,org_id:'synthetic-tenant',role:'manager'};next();
}};
const app=express();app.use(express.json());app.use((req,res,next)=>{
  req.user={id:1,org_id:'synthetic-tenant',role:'manager'};next();
});
app.use('/eam',require('../../api/routes/eam'));
app.use('/procurement',require('../../api/routes/procurement'));
app.use('/iot',require('../../api/routes/iot-devices').ingestion);
app.get('/health',(_req,res)=>res.json({alive:true}));
const server=app.listen(0,'127.0.0.1');
after(()=>new Promise(resolve=>server.close(resolve)));
async function request(path,body,method='POST',headers={}) {
  if(!server.listening)await new Promise(resolve=>server.once('listening',resolve));
  return fetch('http://127.0.0.1:'+server.address().port+path,{
    method,headers:{'content-type':'application/json',...headers},
    body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(3000)
  });
}

test('database outage returns bounded 503 instead of rejected Express handlers across transaction routes',async()=>{
  const scenarios=[
    ['/eam/assets/1/condition/readings',{metric_code:'temperature',value:25,unit:'C',source:'manual'}],
    ['/eam/assets/1/condition/alerts/2/work-order',{}],
    ['/eam/assets/1/condition/alerts/2',{status:'acknowledged'},'PATCH'],
    ['/eam/assets/1/snapshots',{label:'Fixture',kind:'as_built'}],
    ['/eam/assets/1/counters',{operating_hours:10}],
    ['/eam/work-orders/1/release',{}],
    ['/procurement/materials/1/units',{purchase_unit:'BOX',factor:10}],
    ['/procurement/qualifications/1/evidence',{filename:'fixture.pdf',file_data:Buffer.from('%PDF-fixture').toString('base64')}],
    ['/iot/readings',{event_id:'fixture-1',metric_code:'temperature',value:25,unit:'C',recorded_at:new Date().toISOString()},'POST',{'x-device-key':'a'.repeat(64)}]
  ];
  for(const [path,body,method,headers] of scenarios){
    const response=await request(path,body,method,headers);
    assert.equal(response.status,503,path+': '+await response.clone().text());
    assert.doesNotMatch(await response.text(),/SYNTHETIC_PRIVATE_DB_DETAILS|ECONNREFUSED/);
  }
  assert.deepEqual(await (await request('/health',undefined,'GET')).json(),{alive:true});
});

test('rollback failure destroys the connection and still sends the sanitized operation error',async()=>{
  mode='rollback-fails';
  const response=await request('/eam/assets/1/condition/readings',{
    metric_code:'temperature',value:25,unit:'C',source:'manual'
  });
  assert.equal(response.status,500);
  assert.doesNotMatch(await response.text(),/SYNTHETIC_PRIVATE_DB_DETAILS/);
  assert.equal(destroyed,1);assert.equal(released,1);
});
