'use strict';
// Four isolated companies and 25 synthetic identities for cross-client acceptance.
const fs=require('node:fs/promises'),path=require('node:path');
async function main(){
 const {startAuditApp}=require('./audit-app-sandbox.cjs');
 const app=await startAuditApp({port:3001,password:'TCC Fluxo Sintetico 2026!',fixtures:[
  {id:'tcc-alpha',type:'corporate',count:10},{id:'tcc-beta',type:'corporate',count:5},
  {id:'tcc-gamma',type:'corporate',count:5},{id:'tcc-delta',type:'corporate',count:5}
 ]});
 const state=path.resolve(__dirname,'../.runtime/tcc-app-fixtures.json');
 await fs.writeFile(state,JSON.stringify({base:'http://127.0.0.1:3001',companies:4,accounts:app.accounts},null,2),{mode:0o600});
 let closing=false;
 const close=async()=>{if(closing)return;closing=true;await app.close();await fs.unlink(state);};
 const stop=()=>close().catch(()=>{console.error('TCC_APP_CLEANUP_FAILED');process.exitCode=1;});
 process.on('SIGINT',stop);process.on('SIGTERM',stop);
 process.stdin.on('data',data=>{if(String(data).trim()==='stop')stop();});
 setTimeout(stop,4*60*60*1000).unref();
 console.log('TCC_APP_READY companies=4 users=25 port=3001');
}
if(require.main===module)main().catch(error=>{console.error('TCC_APP_FAILED',/^[A-Z0-9_]+$/.test(error.code||error.message)?error.code||error.message:'REVIEW_REQUIRED');process.exitCode=1;});
