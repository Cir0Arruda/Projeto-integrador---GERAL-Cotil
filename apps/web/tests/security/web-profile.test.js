'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{select}=require('../../api/security/web-profile');
test('normal start ignores local profile presence; recovery requires an explicit choice and never silently falls back',async()=>{
 const local={profilePath:()=>'/fixture/local',load:async()=>({PORT:'3000'})};
 const opts={platform:'win32',production:false,requested:undefined,local,exists:async()=>true};
 assert.equal((await select(opts)).name,'vps');
 assert.deepEqual(await select({...opts,requested:'local'}),{name:'local',env:{PORT:'3000'}});
 assert.equal((await select({...opts,requested:'principal'})).name,'vps');
 assert.equal((await select({...opts,production:true})).name,'principal');
 assert.equal((await select({...opts,exists:async()=>false})).name,'vps');
 await assert.rejects(select({...opts,requested:'local',exists:async()=>false}),/LOCAL_PROFILE_MISSING/);
 await assert.rejects(select({...opts,requested:'local',production:true}),/LOCAL_PROFILE_NOT_PRODUCTION/);
 await assert.rejects(select({...opts,requested:'anything'}),/WEB_PROFILE_INVALID/);
 await assert.rejects(select({...opts,requested:'local',local:{...local,load:async()=>{throw Error('decrypt');}}}),/decrypt/);
});
