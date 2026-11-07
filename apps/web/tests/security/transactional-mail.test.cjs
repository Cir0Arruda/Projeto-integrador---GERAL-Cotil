'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {mailbox,configuration,createMailer}=require('../../api/services/transactional-mail');
const {smtpSink,localTransport,fixtureEnv}=require('../helpers/smtp-sink.cjs');
test('SMTP is opt-in, validates config and requires verified TLS with no content access',()=>{
 assert.equal(configuration({}),null);
 for(const address of ['a@example.invalid\r\nBcc:b@example.invalid','a@example.invalid,b@example.invalid','Name <a@example.invalid>',{path:'/private'},'a@x'])assert.throws(()=>mailbox(address));
 for(const config of [{MAIL_PORT:'25'},{MAIL_HOST:'smtp://smtp.example.invalid'},{MAIL_FROM:'a@example.invalid\nX: a'},{MAIL_PASSWORD:''}])assert.throws(()=>configuration({...fixtureEnv,...config}));
 const config=configuration(fixtureEnv);assert.equal(config.options.requireTLS,true);assert.equal(config.options.tls.rejectUnauthorized,true);assert.equal(config.options.tls.minVersion,'TLSv1.2');
 assert.equal(config.options.disableFileAccess,true);assert.equal(config.options.disableUrlAccess,true);assert.equal(config.options.maxRecipients,1);assert.equal(config.options.debug,false);
 const tls=configuration({...fixtureEnv,MAIL_PORT:'465'});assert.equal(tls.options.secure,true);
 assert.equal(createMailer({env:{...fixtureEnv,MAIL_HOST:'bad/host'}}).enabled(),false);
});
test('bounded queue acknowledges before work, releases capacity, and hides raw SMTP errors',async()=>{
 let release;const gate=new Promise(resolve=>{release=resolve;});let calls=0,failures=0;
 const mail=createMailer({env:fixtureEnv,onFailure:()=>failures++});
 for(let n=0;n<8;n++)assert.equal(mail.enqueueRecovery(async()=>{calls++;await gate;}),true);
 assert.equal(calls,0);assert.equal(mail.enqueueRecovery(()=>{}),false);
 release();await mail.idle();assert.equal(calls,8);
 assert.equal(mail.enqueueRecovery(()=>{throw Error('sensitive raw SMTP credentials');}),true);
 await mail.idle();assert.equal(failures,1);await mail.close();
});
test('real loopback SMTP accepts one fixed-envelope invitation; remote content is plain text',async()=>{
 const sink=await smtpSink(),mail=createMailer({env:fixtureEnv,transportFactory:localTransport(sink.port)});
 try{
  await mail.sendInvitation({to:'recipient@example.invalid',code:'ABC12345',organization:'<img src=x>\r\nBcc: other@example.invalid',expiresAt:'2026-12-01T00:00Z'});
  assert.equal(sink.messages.length,1);assert.equal(sink.messages[0].to,'<recipient@example.invalid>');
  assert.match(sink.messages[0].body,/ABC12345/);assert.match(sink.messages[0].body,/Content-Type: text\/plain/);
  assert.doesNotMatch(sink.messages[0].body.split('\r\n\r\n')[0],/Bcc: other/);
  await assert.rejects(()=>mail.sendInvitation({to:'recipient@example.invalid,other@example.invalid',code:'ABC12345',expiresAt:'2026-12-01T00:00Z'}));assert.equal(sink.messages.length,1);
  sink.setReject(true);await assert.rejects(()=>mail.sendInvitation({to:'recipient@example.invalid',code:'ABC12345',expiresAt:'2026-12-01T00:00Z'}));assert.equal(sink.messages.length,1);
 }finally{await mail.close();await sink.close();}
});
test('production TLS policy refuses a real SMTP server that cannot upgrade to TLS',async()=>{
 const sink=await smtpSink();
 const mail=createMailer({env:fixtureEnv,transportFactory:options=>require('../../api/node_modules/nodemailer').createTransport({...options,host:'127.0.0.1',port:sink.port,auth:undefined})});
 try{await assert.rejects(()=>mail.sendInvitation({to:'recipient@example.invalid',code:'ABC12345',expiresAt:'2026-12-01T00:00Z'}));assert.equal(sink.messages.length,0);}finally{await mail.close();await sink.close();}
});
