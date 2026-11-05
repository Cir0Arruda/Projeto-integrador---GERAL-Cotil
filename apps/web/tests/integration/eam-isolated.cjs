'use strict';
// Run legacy rollback integrations only inside a disposable MySQL instance.
const {startSandbox,root}=require('./analytics-sandbox'),{spawn}=require('node:child_process'),path=require('node:path');
async function main(){
 const sandbox=await startSandbox();
 try{
  // These older rollback fixtures use authenticated actor id=1. A fresh sandbox
  // must supply that synthetic user so movement attribution can satisfy its FK.
  await sandbox.admin.execute('INSERT INTO organizations(id,name) VALUES(?,?)',['eam_fixture_actor','Isolated EAM test actor']);
  await sandbox.admin.execute('INSERT INTO users(id,name,email,password_hash,role,org_id,is_active) VALUES(1,?,?,?,?,?,1)',['Synthetic EAM actor','eam-actor@example.invalid','not-a-valid-login-hash','admin','eam_fixture_actor']);
  for(const file of ['eam-db-transaction.js','eam-route-db-transaction.js','eam-completion-db.js'])await new Promise((resolve,reject)=>{
   const child=spawn(process.execPath,[path.join(root,'tests/integration',file)],{cwd:root,env:{...process.env,RUN_EAM_DB_INTEGRATION:'1'},shell:false,windowsHide:true,stdio:'inherit'});
   const timer=setTimeout(()=>{child.kill();reject(Error('EAM_ISOLATED_TIMEOUT'));},60000);child.once('error',reject);child.once('close',code=>{clearTimeout(timer);code===0?resolve():reject(Error('EAM_ISOLATED_FAILED:'+file));});
  });
 }finally{await sandbox.close();}
}
main().catch(e=>{console.error(e.code||e.message);process.exitCode=1;});
