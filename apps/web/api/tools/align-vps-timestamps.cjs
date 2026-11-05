'use strict';
const path=require('node:path'),crypto=require('node:crypto'),{spawn}=require('node:child_process');
async function main(){
  const backup=require('./backup-snapshots.cjs'),env=await require('../security/local-profile').load();
  const original=await backup.verifyBackup(process.argv[2]);
  const db=await require('../node_modules/mysql2/promise').createConnection({host:env.DB_HOST,port:Number(env.DB_PORT),user:env.DB_USER,password:env.DB_PASSWORD,database:env.DB_NAME,dateStrings:true,supportBigNumbers:true,bigNumberStrings:true});
  const directory=path.join(process.env.LOCALAPPDATA,'ASTHA-RAVEN','backups','vps-utc-'+new Date().toISOString().replace(/[:.]/g,'-'));
  try{await backup.backupPair(db,directory);}finally{await db.end();}
  const current=await backup.verifyBackup(directory),bytes=Buffer.from(JSON.stringify({original,current,originalTransferSha:process.argv[3]})),sha=crypto.createHash('sha256').update(bytes).digest('hex');
  await new Promise((resolve,reject)=>{const child=spawn('ssh',['-i',path.join(process.env.LOCALAPPDATA,'ASTHA-RAVEN','deployment','id_ed25519'),'-o','IdentitiesOnly=yes','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','ciroeduardoarrudacosta@136.111.89.192','sudo','-n','/opt/astha/node/bin/node','.astha-deploy/align-timestamps.cjs',sha],{windowsHide:true,shell:false,stdio:['pipe','inherit','inherit']});child.once('error',reject);child.stdin.once('error',reject);child.once('close',code=>code===0?resolve():reject(Error('ALIGNMENT_FAILED')));child.stdin.end(bytes);});
  console.log(JSON.stringify({utcSourceBackup:directory,sourceUnchanged:true}));
}
if(require.main===module)main().catch(e=>{console.error('UTC_ALIGNMENT_FAILED',e.code||(/^[A-Z_]+$/.test(e.message)?e.message:'REVIEW_REQUIRED'));process.exitCode=1;});
