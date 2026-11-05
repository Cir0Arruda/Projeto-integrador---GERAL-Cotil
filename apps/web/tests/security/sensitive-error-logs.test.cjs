'use strict';
const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const express=require('../../api/node_modules/express');
const safeErrorLog=require('../../api/security/safe-error-log');
const synthetic='SYNTHETIC_PRIVATE_CONTACT_BODY';
const failure=Object.assign(new Error('SQL failed: '+synthetic),{
  code:'ER_DATA_TOO_LONG',sql:"INSERT INTO contact_messages VALUES ('"+synthetic+"')",
  sqlMessage:'Invalid content '+synthetic,cause:{password:synthetic}
});
require.cache[require.resolve('../../api/database/connection')]={exports:{pool:{execute:async()=>{throw failure;}},readWithRetry:async()=>{throw failure;}}};
const app=express();app.use(express.json());app.use('/contact',require('../../api/routes/contact'));
const server=app.listen(0,'127.0.0.1');
after(()=>new Promise(resolve=>server.close(resolve)));

test('support write failure never serializes private SQL, parameters or stack to logs/response',async()=>{
  if(!server.listening)await new Promise(resolve=>server.once('listening',resolve));
  const logs=[],original=console.error;
  console.error=(...args)=>logs.push(args);
  try {
    const response=await fetch('http://127.0.0.1:'+server.address().port+'/contact',{
      method:'POST',headers:{'content-type':'application/json'},
      body:JSON.stringify({name:'Synthetic',email:'fixture@example.invalid',message:synthetic})
    });
    assert.equal(response.status,500);
    assert.deepEqual(logs,[['POST /contact error:','ER_DATA_TOO_LONG']]);
    assert.doesNotMatch(JSON.stringify(logs)+await response.text(),new RegExp(synthetic));
  } finally { console.error=original; }
});

test('unexpected error fields and multiline codes cannot inject content into logs',()=>{
  const logs=[],original=console.error;
  console.error=(...args)=>logs.push(args);
  try {
    safeErrorLog('[DB_OPERATION]',{code:'ER_FAILURE\n'+synthetic,message:synthetic});
    safeErrorLog('[DB_OPERATION]',{name:synthetic,sql:synthetic});
    assert.deepEqual(logs,[['[DB_OPERATION]','UNEXPECTED_ERROR'],['[DB_OPERATION]','UNEXPECTED_ERROR']]);
  } finally { console.error=original; }
});
