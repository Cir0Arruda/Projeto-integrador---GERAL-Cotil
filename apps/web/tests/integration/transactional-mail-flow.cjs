'use strict';
// Real SQL, HTTP and SMTP protocol; all data/recipients are synthetic and owned.
const assert=require('node:assert/strict');
const {smtpSink,localTransport,fixtureEnv}=require('../helpers/smtp-sink.cjs');
const mailModule=require('../../api/services/transactional-mail');
const {startAuditApp}=require('./audit-app-sandbox.cjs');
async function main(){
 let app,phase='setup',failures=0;const sink=await smtpSink();
 const mail=mailModule.createMailer({env:fixtureEnv,transportFactory:localTransport(sink.port),onFailure:()=>failures++});
 mailModule.mailer=mail;
 async function request(path,account,method='GET',body,status=200){
  const response=await fetch('http://127.0.0.1:3001/api'+path,{method,redirect:'error',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json',...(account?{Authorization:'Bearer '+account.token}:{})},...(body?{body:JSON.stringify(body)}:{})});
  const data=await response.json();assert.equal(response.status,status,'Unexpected HTTP status at '+path);return data;
 }
 const messageCode=index=>{const body=sink.messages[index].body.split('\r\n\r\n').slice(1).join('\r\n\r\n');const code=body.match(/digo: ([\w-]{22})/);assert.ok(code,'Recovery message has a usable code');return code[1];};
 try{
  app=await startAuditApp({port:3001,fixtures:[{id:'audit-mail',type:'corporate',count:5},{id:'audit-other',type:'corporate'}]});
  assert.match(app.db,/^astha_test_[a-f0-9]+$/);
  const [owner,,provider,,viewer,outsider]=app.accounts;
  for(const account of [owner,viewer,outsider]){const login=await request('/auth/login',null,'POST',{email:account.email,password:account.password});account.token=login.token;}
  const accountService=require('../../api/services/account');
  const ownerReq={user:owner,headers:{authorization:'Bearer '+owner.token}};
  const saved=await accountService.recoveryCodes(app.pool,ownerReq,{current_password:owner.password});assert.equal(saved.codes.length,8);
  assert.deepEqual(await request('/account/recovery-options'),{emailRecoveryAvailable:true});
  phase='generic-request-and-storage';
  const known=await request('/account/recover/email',null,'POST',{email:owner.email});
  const absent=await request('/account/recover/email',null,'POST',{email:'absent@example.invalid'});
  assert.deepEqual(known,absent);assert.deepEqual(Object.keys(known),['message']);await mail.idle();assert.equal(sink.messages.length,1);
  const code=messageCode(0),[stored]=await app.pool.execute('SELECT token,expires_at,created_at FROM password_resets WHERE user_id=?',[owner.id]);
  assert.equal(stored.filter(row=>row.token.startsWith('account-recovery:')).length,8);
  const emailed=stored.find(row=>row.token.startsWith('account-email:'));assert.ok(emailed);assert.ok(!emailed.token.includes(code));
  assert.equal(emailed.expires_at-emailed.created_at,15*60*1000);
  phase='cooldown-and-provider';
  await app.pool.execute("UPDATE users SET provider='google',provider_id='synthetic-google' WHERE id=?",[provider.id]);
  assert.deepEqual(await request('/account/recover/email',null,'POST',{email:provider.email}),known);
  assert.deepEqual(await request('/account/recover/email',null,'POST',{email:owner.email}),known);
  await mail.idle();assert.equal(sink.messages.length,1);
  phase='one-time-reset-and-session-revocation';
  const next='Synthetic changed password 2026!';
  await request('/account/recover',null,'POST',{email:owner.email,code,new_password:next});
  await assert.rejects(()=>accountService.recover(app.pool,{email:owner.email,code,new_password:next}),error=>error.status===400);
  await request('/auth/me',owner,'GET',null,401);
  await request('/auth/login',null,'POST',{email:owner.email,password:owner.password},401);
  const login=await request('/auth/login',null,'POST',{email:owner.email,password:next});owner.token=login.token;
  const [[remaining]]=await app.pool.execute('SELECT COUNT(*) AS n FROM password_resets WHERE user_id=?',[owner.id]);assert.equal(remaining.n,0);
  await request('/account/recover/email',null,'POST',{email:owner.email},429);
  phase='expiry-and-send-failure';
  await accountService.requestEmailRecovery(app.pool,{email:owner.email},mail);await mail.idle();const expiring=messageCode(1);
  await app.pool.execute('UPDATE password_resets SET expires_at=DATE_SUB(NOW(),INTERVAL 1 MINUTE) WHERE user_id=?',[owner.id]);
  await assert.rejects(()=>accountService.recover(app.pool,{email:owner.email,code:expiring,new_password:next}),error=>error.status===400);
  await app.pool.execute('UPDATE password_resets SET expires_at=DATE_ADD(NOW(),INTERVAL 15 MINUTE) WHERE user_id=?',[owner.id]);
  await accountService.recoveryCodes(app.pool,{user:owner,headers:{authorization:'Bearer '+owner.token}},{current_password:next});
  await assert.rejects(()=>accountService.recover(app.pool,{email:owner.email,code:expiring,new_password:next}),error=>error.status===400);
  sink.setReject(true);
  assert.deepEqual(await accountService.requestEmailRecovery(app.pool,{email:owner.email},mail),known);await mail.idle();assert.equal(failures,1);
  const [[failedTokens]]=await app.pool.execute('SELECT COUNT(*) AS n FROM password_resets WHERE user_id=? AND token LIKE ?',[owner.id,'account-email:%']);assert.equal(failedTokens.n,0);
  const [[savedTokens]]=await app.pool.execute('SELECT COUNT(*) AS n FROM password_resets WHERE user_id=? AND token LIKE ?',[owner.id,'account-recovery:%']);assert.equal(savedTokens.n,8);sink.setReject(false);
  phase='explicit-invite-delivery-and-tenant-boundary';
  const before=sink.messages.length;
  const invite=await request('/org/invites',owner,'POST',{email:'recipient@example.invalid',role:'viewer'},201);
  assert.ok(Number.isInteger(invite.id));assert.equal(sink.messages.length,before,'Creating a code does not send mail');
  await request('/org/invites/'+invite.id+'/email',outsider,'POST',{},404);
  await request('/org/invites/'+invite.id+'/email',viewer,'POST',{},403);
  await request('/org/invites/'+invite.id+'/email',owner,'POST',{});assert.equal(sink.messages.length,before+1);assert.match(sink.messages.at(-1).body,new RegExp(invite.code));
  await app.pool.execute('UPDATE org_invites SET used_at=NOW() WHERE id=?',[invite.id]);
  await request('/org/invites/'+invite.id+'/email',owner,'POST',{},404);
  const open=await request('/org/invites',owner,'POST',{role:'viewer'},201);await request('/org/invites/'+open.id+'/email',owner,'POST',{},400);
  const expired=await request('/org/invites',owner,'POST',{email:'recipient@example.invalid',role:'viewer'},201);
  await app.pool.execute('UPDATE org_invites SET expires_at=DATE_SUB(NOW(),INTERVAL 1 MINUTE) WHERE id=?',[expired.id]);await request('/org/invites/'+expired.id+'/email',owner,'POST',{},404);
  const rejected=await request('/org/invites',owner,'POST',{email:'recipient@example.invalid',role:'viewer'},201);sink.setReject(true);
  await request('/org/invites/'+rejected.id+'/email',owner,'POST',{},503);
  const [[retained]]=await app.pool.execute('SELECT COUNT(*) AS n FROM org_invites WHERE id=? AND used_at IS NULL',[rejected.id]);assert.equal(retained.n,1);
  phase='read-only-mail-schema-deployment-gate';
  const {validateMailSchema}=require('../../api/security/production-config');
  assert.equal(await validateMailSchema(app.pool,{MAIL_ENABLED:'true'}),true);
  // Alter only this disposable fixture to reproduce an older incompatible schema.
  await app.admin.query('ALTER TABLE password_resets RENAME COLUMN created_at TO qa_created_at');
  await assert.rejects(()=>validateMailSchema(app.pool,{MAIL_ENABLED:'true'}),/MAIL_SCHEMA_UNAVAILABLE/);
  assert.equal(await validateMailSchema(app.pool,{MAIL_ENABLED:'false'}),false);
  await app.admin.query('ALTER TABLE password_resets RENAME COLUMN qa_created_at TO created_at');
  assert.equal(await validateMailSchema(app.pool,{MAIL_ENABLED:'true'}),true);
  console.log('TRANSACTIONAL_MAIL_SQL_HTTP_SMTP_PASSED (owned local sink only; external delivery not tested)');
 }catch(error){console.error('TRANSACTIONAL_MAIL_FLOW_FAILED',phase,/^[A-Z0-9_]+$/.test(error.code||'')?error.code:'VALIDATION_FAILED');if(error.message?.startsWith('Unexpected HTTP status'))console.error(error.message.slice(0,250));process.exitCode=1;}
 finally{await mail.close();if(app)await app.close();await sink.close();}
}
if(require.main===module)main();
module.exports={main};
