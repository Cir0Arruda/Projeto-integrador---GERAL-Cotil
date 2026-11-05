'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),{validateProduction}=require('../../api/security/production-config');
test('VPS production allows only the private loopback MySQL topology and its designated schema',()=>{
  const env={NODE_ENV:'production',HOST:'127.0.0.1',DB_TOPOLOGY:'vps-local',DB_HOST:'127.0.0.1',DB_PORT:'3306',DB_NAME:'astha_raven_prod',DB_SSL_REQUIRED:'false'};
  assert.equal(validateProduction(env),'vps-local');
  for(const change of [{DB_HOST:'136.111.89.192'},{DB_HOST:'database.example.invalid'},{DB_NAME:'mysql'},{HOST:'0.0.0.0'},{DB_TOPOLOGY:'anything'},{DB_PORT:'3307'}])assert.throws(()=>validateProduction({...env,...change}));
});
test('retired COTIL and missing topologies cannot start production even with a CA',()=>{
  const env={NODE_ENV:'production',HOST:'127.0.0.1',DB_NAME:'cl205131',DB_SSL_REQUIRED:'true',DB_SSL_CA_FILE:'/etc/astha/cotil-ca.pem'};
  assert.throws(()=>validateProduction(env),/DATABASE_TOPOLOGY_INVALID/);
  assert.throws(()=>validateProduction({...env,DB_TOPOLOGY:'cotil'}),/DATABASE_TOPOLOGY_INVALID/);
  assert.throws(()=>validateProduction({...env,DB_SSL_REQUIRED:'false'}));
  assert.throws(()=>validateProduction({...env,DB_SSL_CA_FILE:''}));
});
test('raw API database connection rejects COTIL before acquiring a socket',()=>{
 const {validateDatabaseDestination}=require('../../api/security/database-destination');
 for(const env of [{DB_HOST:'clone.cotil.unicamp.br'},{DB_HOST:'CLONE.COTIL.UNICAMP.BR.'},{DB_HOST:'143.106.241.4'},{DB_NAME:'cl205131'}])assert.throws(()=>validateDatabaseDestination(env),/RETIRED_DATABASE_DESTINATION/);
 assert.doesNotThrow(()=>validateDatabaseDestination({DB_HOST:'127.0.0.1',DB_NAME:'astha_raven_lab'}));
});
