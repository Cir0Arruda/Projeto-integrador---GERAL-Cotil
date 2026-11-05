'use strict';
// Archive obsolete credentials with Windows DPAPI, then remove the retired SQL configuration.
const fs=require('node:fs/promises'),path=require('node:path');
async function main(){
 if(process.platform!=='win32')throw Error('WINDOWS_REQUIRED');
 const root=path.resolve(__dirname,'../..'),dotenv=require('../node_modules/dotenv'),{protectWindows}=require('./backup-snapshots.cjs');
 const directory=path.join(process.env.LOCALAPPDATA,'ASTHA-RAVEN','retired-cotil',new Date().toISOString().replace(/[:.]/g,'-'));let count=0;
 for(const [relative,name] of [['api/.env','web.env.dpapi'],['electron/src/main/.env','desktop.env.dpapi']]){
  const file=path.join(root,relative);let bytes;try{bytes=await fs.readFile(file);}catch(e){if(e.code==='ENOENT')continue;throw e;}
  const env=dotenv.parse(bytes),host=String(env.DB_HOST||'').toLowerCase();
  if(env.DB_NAME!=='cl205131'&&!host.includes('cotil.unicamp.br')&&host!=='143.106.241.4')continue;
  await fs.mkdir(directory,{recursive:true});const encrypted=await protectWindows(bytes,directory);bytes.fill(0);
  await fs.writeFile(path.join(directory,name),encrypted,{flag:'wx'});
  for(const key of Object.keys(env))if(key.startsWith('DB_')||key==='ASTHA_ELECTRON_COTIL')delete env[key];
  env.ASTHA_SERVER_URL=require('../security/client-deployment').DEFAULT_SERVER_URL;env.ASTHA_WEB_PROFILE='vps';
  await fs.writeFile(file,'# SQL COTIL retired. Start the VPS client by default; local recovery uses its protected profile.\n'+Object.entries(env).map(([k,v])=>k+'='+JSON.stringify(v)).join('\n')+'\n');count++;
 }
 console.log(JSON.stringify({retiredConfigurations:count,encryptedArchive:count?directory:null,credentialsPrinted:false}));
}
if(require.main===module)main().catch(e=>{console.error('CONFIG_RETIREMENT_FAILED',e.code||'REVIEW_REQUIRED');process.exitCode=1;});
