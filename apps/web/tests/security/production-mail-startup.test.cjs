'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {validateProduction,validateMailSchema}=require('../../api/security/production-config');
const {fixtureEnv}=require('../helpers/smtp-sink.cjs');
const production={NODE_ENV:'production',HOST:'127.0.0.1',DB_TOPOLOGY:'vps-local',DB_HOST:'127.0.0.1',DB_PORT:'3306',DB_NAME:'astha_raven_prod',DB_SSL_REQUIRED:'false'};
test('production rejects explicitly enabled incomplete/unsafe mail before opening SQL or HTTP',()=>{
 for(const change of [{MAIL_ENABLED:'yes'},{MAIL_ENABLED:'true'},{...fixtureEnv,MAIL_PORT:'25'},{...fixtureEnv,MAIL_FROM:'sender@example.invalid\r\nBcc:recipient@example.invalid'}])assert.throws(()=>validateProduction({...production,...change}),/MAIL_CONFIG_INVALID/);
 for(const change of [{},{MAIL_ENABLED:''},{MAIL_ENABLED:'false'},fixtureEnv,{...fixtureEnv,MAIL_PORT:'465'}])assert.equal(validateProduction({...production,...change}),'vps-local');
});
test('mail schema gate is opt-in, read-only and never propagates raw database details',async()=>{
 let calls=0;const db={execute:async()=>{calls++;throw Object.assign(Error('private interpolated SQL or credentials'),{code:'ER_BAD_FIELD_ERROR'});}};
 assert.equal(await validateMailSchema(db,{}),false);assert.equal(calls,0);
 await assert.rejects(()=>validateMailSchema(db,{MAIL_ENABLED:'true'}),error=>error.message==='MAIL_SCHEMA_UNAVAILABLE');assert.equal(calls,1);
});
test('actual production entrypoint closes SQL and refuses listener when the mail gate fails',async()=>{
 for(const missingSchema of [true,false]){
  const calls=[];const pool={execute:async sql=>{
   calls.push(sql);
   if(sql.startsWith('SELECT INDEX_NAME'))return [[{columns_list:'org_id,code'}]];
   if(sql.startsWith('SELECT user_id,token')&&missingSchema)throw Error('synthetic missing column');
   return [[]];
  },end:async()=>{calls.push('closed');}};
  const module={exports:{}};
  const controlledRequire=name=>{
   if(name==='./security/production-config')return{validateProduction:()=>validateProduction({...production,...fixtureEnv}),validateMailSchema:db=>validateMailSchema(db,{MAIL_ENABLED:'true'})};
   if(name==='./database/connection')return{pool};
   if(name==='./server')return{startServer:async()=>{calls.push('listening');}};
   throw Error('Unexpected production dependency');
  };
  vm.runInNewContext(fs.readFileSync('api/production-start.cjs','utf8'),{require:controlledRequire,module});
  if(missingSchema){await assert.rejects(()=>module.exports.main(),/MAIL_SCHEMA_UNAVAILABLE/);assert.ok(calls.includes('closed'));assert.ok(!calls.includes('listening'));}
  else{await module.exports.main();assert.ok(calls.includes('listening'));assert.ok(!calls.includes('closed'));}
 }
});
