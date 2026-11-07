'use strict';
// Provider signature validation + real local SQL/HTTP. Synthetic issuer keys,
// identities and workspaces only; never automates a real Google account.
const assert=require('node:assert/strict'),crypto=require('node:crypto');
const jwt=require('../../api/node_modules/jsonwebtoken');
const {startAuditApp}=require('./audit-app-sandbox.cjs');
async function main(){
 const realFetch=global.fetch,clientId='123456789-ownedfixture.apps.googleusercontent.com';
 const {privateKey,publicKey}=crypto.generateKeyPairSync('rsa',{modulusLength:2048});
 const jwk={...publicKey.export({format:'jwk'}),kid:'owned-onboarding-fixture',use:'sig'};
 process.env.GOOGLE_CLIENT_ID=clientId;
 global.fetch=(url,options)=>url==='https://www.googleapis.com/oauth2/v3/certs'
  ?Promise.resolve(new Response(JSON.stringify({keys:[jwk]}),{status:200})):realFetch(url,options);
 let app,phase='owned-fixture';
 async function request(path,token,method='GET',body,status=200){
  const r=await realFetch('http://127.0.0.1:3001/api'+path,{method,redirect:'error',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(body?{body:JSON.stringify(body)}:{})});
  assert.equal(r.status,status,'Unexpected status at '+path);return r.json();
 }
 async function google(subject){
  const config=await request('/auth/oauth/config');const nonce=config.google.nonce;
  const credential=jwt.sign({sub:subject,email:subject+'@example.invalid',email_verified:true,name:'Synthetic Google',nonce},privateKey,{algorithm:'RS256',audience:clientId,issuer:'https://accounts.google.com',expiresIn:'5m',keyid:jwk.kid});
  return request('/auth/oauth/google',null,'POST',{credential,nonce});
 }
 async function complete(account,type,name){
  await request('/workspace/type',account.token,'PUT',{type});
  await request('/auth/profile',account.token,'PUT',{name:'Synthetic',surname:'Person',phone:'000000',country:'Brasil'});
  const org=await request('/org/me',account.token);
  await request('/org/me',account.token,'PUT',{name,cnpj:org.cnpj,email:org.email,phone:org.phone,address:org.address,city:org.city,state:org.state});
  assert.equal((await request('/workspace/context',account.token)).setupDone,false);
  await request('/org/complete-setup',account.token,'POST',{});
  assert.equal((await request('/workspace/context',account.token)).setupDone,true);
  assert.equal((await request('/auth/me',account.token)).setup_done,true);
 }
 try{
  app=await startAuditApp({port:3001,fixtures:[{id:'audit-team',type:'corporate'}]});assert.match(app.db,/^astha_test_[a-f0-9]+$/);
  phase='google-pending-owner';const account=await google('pending-google');
  assert.equal(account.user.setup_done,false);assert.equal(account.user.role,'superadmin');
  // Reproduce the reported personal default without completing the workspace.
  await app.pool.execute("UPDATE organizations SET workspace_type='personal' WHERE id=?",[account.user.org_id]);
  assert.deepEqual(await request('/workspace/context',account.token),{type:'personal',setupDone:false});
  await app.pool.execute('UPDATE organizations SET email=?,phone=?,address=?,city=?,state=? WHERE id=?',['org@example.invalid','preserved-phone','preserved-address','preserved-city','SP',account.user.org_id]);
  phase='explicit-corporate-completion';await complete(account,'corporate','Synthetic company');
  const saved=await request('/org/me',account.token);assert.equal(saved.email,'org@example.invalid');assert.equal(saved.address,'preserved-address');
  phase='repeat-google-preserves-account';const repeated=await google('pending-google');
  assert.equal(repeated.user.id,account.user.id);assert.equal(repeated.user.org_id,account.user.org_id);assert.equal(repeated.user.setup_done,true);
  await request('/workspace/type',repeated.token,'PUT',{type:'personal'},403);
  const [[users]]=await app.pool.execute('SELECT COUNT(*) AS n FROM users WHERE email=?',['pending-google@example.invalid']);assert.equal(users.n,1);
  phase='explicit-personal-completion';const personal=await google('personal-google');await complete(personal,'personal','Synthetic home');
  assert.deepEqual(await request('/workspace/context',personal.token),{type:'personal',setupDone:true});
  phase='google-member-invitation';const team=app.accounts[0];
  const login=await request('/auth/login',null,'POST',{email:team.email,password:team.password});
  const invited=await google('invited-google');
  const invite=await request('/org/invites',login.token,'POST',{email:invited.user.email,role:'viewer'},201);
  const joined=await request('/org/join',invited.token,'POST',{code:invite.code});
  const member=await request('/auth/me',joined.token);assert.equal(member.id,invited.user.id);assert.equal(member.org_id,team.org_id);assert.equal(member.role,'viewer');assert.equal(member.setup_done,true);
  await request('/auth/me',invited.token,'GET',null,401);
  // Joining moves membership, not unrelated workspace data. The existing API
  // preserves the provisional organization instead of deleting it implicitly.
  const [[pendingOrg]]=await app.pool.execute('SELECT COUNT(*) AS n FROM organizations WHERE id=?',[invited.user.org_id]);assert.equal(pendingOrg.n,1);
  console.log('GOOGLE_ONBOARDING_SQL_HTTP_PASSED (synthetic provider keys; real Google manual retest still required)');
 }catch(error){console.error('GOOGLE_ONBOARDING_SQL_HTTP_FAILED',phase,/^[A-Z_]+$/.test(error.code||'')?error.code:'VALIDATION_FAILED');if(error.message?.startsWith('Unexpected status'))console.error(error.message.slice(0,180));process.exitCode=1;}
 finally{if(app)await app.close();global.fetch=realFetch;}
}
if(require.main===module)main();
module.exports={main};
