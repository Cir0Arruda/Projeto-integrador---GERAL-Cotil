'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),{spawn}=require('node:child_process');
async function main(){
 const directory=process.argv[2];if(!directory)throw Error('VERIFIED_BACKUP_PATH_REQUIRED');
 const snapshot=await require('./backup-snapshots.cjs').verifyBackup(path.resolve(directory));
 const bytes=Buffer.from(JSON.stringify(snapshot));if(bytes.length>64*1024*1024)throw Error('AUDIT_LIMIT');
 const output=await new Promise((resolve,reject)=>{
  const child=spawn('ssh',['-i',path.join(process.env.LOCALAPPDATA,'ASTHA-RAVEN','deployment','id_ed25519'),'-o','IdentitiesOnly=yes','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8','ciroeduardoarrudacosta@136.111.89.192','sudo','-n','/opt/astha/node/bin/node','.astha-deploy/verify-migration.cjs'],{windowsHide:true,shell:false,stdio:['pipe','pipe','inherit']});
  let result='';const timer=setTimeout(()=>{child.kill();reject(Error('AUDIT_TIMEOUT'));},120000);
  child.stdout.on('data',b=>{result+=b;if(result.length>1024*1024)child.kill();});child.once('error',reject);child.stdin.once('error',()=>reject(Error('AUDIT_CHANNEL_FAILED')));
  child.once('close',code=>{clearTimeout(timer);try{const data=JSON.parse(result);resolve({code,data});}catch{reject(Error('AUDIT_RESULT_INVALID'));}});child.stdin.end(bytes);
 });
 const report=path.resolve(__dirname,'../../tests/.runtime/vps-migration-verification.json');await fs.mkdir(path.dirname(report),{recursive:true});await fs.writeFile(report,JSON.stringify(output.data,null,2));
 console.log(JSON.stringify({passed:output.data.passed,tables:output.data.sourceTables,sourceRows:output.data.sourceRows,missingColumns:output.data.missingColumns,unexplainedMissingRows:output.data.unexplainedMissingRows,foreignKeyOrphans:output.data.foreignKeyOrphans,report}));process.exitCode=output.code;
}
if(require.main===module)main().catch(e=>{console.error('MIGRATION_VERIFICATION_FAILED',e.code||(/^[A-Z_]+$/.test(e.message)?e.message:'REVIEW_REQUIRED'));process.exitCode=1;});
