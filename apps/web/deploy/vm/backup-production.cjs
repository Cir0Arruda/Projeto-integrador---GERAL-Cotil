'use strict';
// Emit only encrypted SQLite containers over the authenticated SSH channel.
const fs=require('node:fs/promises'),path=require('node:path'),{createRequire}=require('node:module');
const load=createRequire('/opt/astha/releases/current/api/package.json');
async function main(){
 if(process.getuid?.()!==0)throw Error('ADMIN_REQUIRED');
 let input='';for await(const chunk of process.stdin){input+=chunk;if(input.length>128)throw Error('INVALID_BACKUP_KEY');}
 if(!/^[a-f0-9]{64}$/.test(input))throw Error('INVALID_BACKUP_KEY');const key=Buffer.from(input,'hex');input='';
 const base='/var/lib/astha-backup';await fs.mkdir(base,{recursive:true,mode:0o700});const directory=await fs.mkdtemp(path.join(base,'snapshot-'));
 const db=await load('mysql2/promise').createConnection({socketPath:'/run/mysqld/mysqld.sock',user:'root',database:'astha_raven_prod',dateStrings:true,supportBigNumbers:true,bigNumberStrings:true,multipleStatements:false});
 try{
  const manifest=await require('./backup-snapshots.cjs').backupPair(db,directory,{key:Buffer.from(key),protect:async()=> 'key-held-only-by-requesting-Windows-client'});
  const copies={};for(const name of ['backup-a.sqlite','backup-b.sqlite'])copies[name]=(await fs.readFile(path.join(directory,name))).toString('base64');
  process.stdout.write(JSON.stringify({manifest,copies}));
 }finally{
  key.fill(0);await db.end();const real=await fs.realpath(directory);if(path.dirname(real)!==base||!path.basename(real).startsWith('snapshot-'))throw Error('BACKUP_CLEANUP_PATH_INVALID');await fs.rm(real,{recursive:true,force:true});
 }
}
if(require.main===module)main().catch(e=>{console.error('VPS_BACKUP_FAILED',e.code||(/^[A-Z_]+$/.test(e.message)?e.message:'REVIEW_REQUIRED'));process.exitCode=1;});
