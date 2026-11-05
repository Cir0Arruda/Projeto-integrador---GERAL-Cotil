'use strict';
// Only the previously authorized local lab is read. Source data is never changed.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto'),{spawn}=require('node:child_process');
async function main(){
  const env=await require('../security/local-profile').load(),mysql=require('../node_modules/mysql2/promise'),backup=require('./backup-snapshots.cjs');
  const db=await mysql.createConnection({host:env.DB_HOST,port:Number(env.DB_PORT),database:env.DB_NAME,user:env.DB_USER,password:env.DB_PASSWORD,dateStrings:true,supportBigNumbers:true,bigNumberStrings:true,multipleStatements:false,flags:'-LOCAL_FILES'});
  const directory=path.join(process.env.LOCALAPPDATA,'ASTHA-RAVEN','backups','vps-migration-'+new Date().toISOString().replace(/[:.]/g,'-'));
  try{await backup.backupPair(db,directory);}finally{await db.end();}
  const snapshot=await backup.verifyBackup(directory),provider={},config=require('../node_modules/dotenv').parse(await fs.readFile(path.resolve(__dirname,'../.env')));
  for(const name of ['GEMINI_API_KEY','GEMINI_MODEL'])if(config[name])provider[name]=config[name];
  const bytes=Buffer.from(JSON.stringify({snapshot,provider})),sha256=crypto.createHash('sha256').update(bytes).digest('hex');
  if(bytes.length>64*1024*1024)throw Error('TRANSFER_TOO_LARGE');
  const key=path.join(process.env.LOCALAPPDATA,'ASTHA-RAVEN','deployment','id_ed25519');
  await new Promise((resolve,reject)=>{
    const child=spawn('ssh',['-i',key,'-o','IdentitiesOnly=yes','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8','ciroeduardoarrudacosta@136.111.89.192','sudo','-n','/opt/astha/node/bin/node','.astha-deploy/import-vps.cjs',sha256],{windowsHide:true,shell:false,stdio:['pipe','inherit','inherit']});
    child.once('error',reject);child.stdin.once('error',()=>reject(Error('TRANSFER_CHANNEL_FAILED')));child.once('close',code=>code===0?resolve():reject(Error('VPS_IMPORT_FAILED')));child.stdin.end(bytes);
  });
  console.log(JSON.stringify({sourceBackup:directory,sourceUnchanged:true,encryptedTransport:'SSH',plaintextExportWritten:false}));
}
if(require.main===module)main().catch(e=>{console.error('LOCAL_TRANSFER_FAILED',e.code||(/^[A-Z_]+$/.test(e.message)?e.message:'REVIEW_REQUIRED'));process.exitCode=1;});
module.exports={main};
