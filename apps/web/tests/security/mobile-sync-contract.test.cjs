'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
const sync=require('../../api/services/mobile-sync');
test('offline protocol accepts only closed routes and methods; account and database writes stay online',()=>{
  const op={id:randomUUID(),method:'POST',path:'/api/movements/entry',body:{code:'TEST',quantity:.125}};
  assert.equal(sync.operation(op).kind,'movement');
  for(const path of ['/api/account/password','/api/auth/users','/api/eam/assets','https://example.invalid/api/materials','/api/materials/../account'])assert.throws(()=>sync.operation({...op,path}));
  for(const change of [{method:'GET'},{id:'1'},{body:[]},{body:null},{body:{value:'x'.repeat(1100000)}}])assert.throws(()=>sync.operation({...op,...change}));
});
test('material concurrency tag is stable across key order and changes for values or timestamps',()=>{
  const a={id:1,quantity:'1.000',updated_at:new Date('2026-10-20T00:00:00Z')};
  assert.equal(sync.materialTag(a),sync.materialTag({updated_at:a.updated_at,quantity:a.quantity,id:1,sync_etag:'ignored'}));
  assert.notEqual(sync.materialTag(a),sync.materialTag({...a,quantity:'2.000'}));
  assert.notEqual(sync.materialTag(a),sync.materialTag({...a,updated_at:new Date('2026-10-21T00:00:00Z')}));
});
test('reverse proxy trust is explicit and cannot expose a trusted forwarded-header listener',()=>{
  const configure=require('../../api/security/proxy'),calls=[],app={set:(...args)=>calls.push(args)};
  configure(app,{});assert.equal(calls.length,0);
  assert.throws(()=>configure(app,{TRUST_PROXY_LOOPBACK:'true',HOST:'0.0.0.0'}),/LOOPBACK/);
  configure(app,{TRUST_PROXY_LOOPBACK:'true',HOST:'127.0.0.1'});assert.deepEqual(calls,[['trust proxy','loopback']]);
});
