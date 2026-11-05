'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto'),{spawn}=require('node:child_process');
async function main(){
 if(process.platform!=='win32')throw Error('WINDOWS_DPAPI_BACKUP_REQUIRED');
 const {protectWindows,verifyBackup}=require('./backup-snapshots.cjs'),key=crypto.randomBytes(32);
 const directory=path.join(process.env.LOCALAPPDATA,'ASTHA-RAVEN','backups','vps-production-'+new Date().toISOString().replace(/[:.]/g,'-'));
 await fs.mkdir(directory,{recursive:true});const wrapped=await protectWindows(key,directory);
 try{
  const result=await new Promise((resolve,reject)=>{
   const child=spawn('ssh',['-i',path.join(process.env.LOCALAPPDATA,'ASTHA-RAVEN','deployment','id_ed25519'),'-o','IdentitiesOnly=yes','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8','ciroeduardoarrudacosta@136.111.89.192','sudo','-n','/opt/astha/node/bin/node','.astha-deploy/backup-production.cjs'],{windowsHide:true,shell:false,stdio:['pipe','pipe','inherit']});
   let bytes=0;const chunks=[],timer=setTimeout(()=>{child.kill();reject(Error('VPS_BACKUP_TIMEOUT'));},120000);
   child.stdout.on('data',b=>{bytes+=b.length;if(bytes>192*1024*1024){child.kill();return;}chunks.push(b);});child.once('error',reject);child.stdin.once('error',()=>reject(Error('VPS_BACKUP_CHANNEL_FAILED')));
   child.once('close',code=>{clearTimeout(timer);if(code!==0)return reject(Error('VPS_BACKUP_FAILED'));try{resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));}catch{reject(Error('VPS_BACKUP_INVALID'));}});child.stdin.end(key.toString('hex'));
  });
  await fs.writeFile(path.join(directory,'recovery-key.dpapi'),wrapped,{flag:'wx'});await fs.writeFile(path.join(directory,'manifest.json'),JSON.stringify(result.manifest,null,2),{flag:'wx'});
  for(const name of ['backup-a.sqlite','backup-b.sqlite'])await fs.writeFile(path.join(directory,name),Buffer.from(result.copies[name],'base64'),{flag:'wx'});
  let verified;for(const copy of ['backup-a.sqlite','backup-b.sqlite'])verified=await verifyBackup(directory,{key:Buffer.from(key),copy});
  console.log(JSON.stringify({status:'VPS_BACKUP_VERIFIED',directory,tables:verified.tables.length,rows:verified.manifest.tables.reduce((n,t)=>n+t.rows,0),copies:2,encrypted:true,keyProtection:'Windows DPAPI',source:'astha_raven_prod'}));
 }finally{key.fill(0);}
}
if(require.main===module)main().catch(e=>{console.error('VPS_BACKUP_FAILED',e.code||(/^[A-Z_]+$/.test(e.message)?e.message:'REVIEW_REQUIRED'));process.exitCode=1;});
