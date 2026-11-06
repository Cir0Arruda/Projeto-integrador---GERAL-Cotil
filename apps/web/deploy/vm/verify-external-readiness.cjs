'use strict';
// Configuration-presence check only. Never print credentials or environment values.
const fs=require('node:fs/promises'),{createRequire}=require('node:module');
async function main(){
 if(process.getuid?.()!==0)throw Error('ADMIN_REQUIRED');
 const load=createRequire('/opt/astha/releases/current/api/package.json');
 const env=load('dotenv').parse(await fs.readFile('/etc/astha/runtime.env'));
 const present=key=>typeof env[key]==='string'&&env[key].trim().length>0;
 console.log(JSON.stringify({status:'EXTERNAL_READINESS',googleClientConfigured:present('GOOGLE_CLIENT_ID'),geminiKeyConfigured:present('GEMINI_API_KEY'),geminiModelConfigured:present('GEMINI_MODEL'),mailTransportConfigured:['SMTP_HOST','RESEND_API_KEY','SENDGRID_API_KEY'].some(present)}));
 if(process.argv.includes('--probe-gemini')){
  if(!present('GEMINI_API_KEY')){console.log(JSON.stringify({status:'GEMINI_UNCONFIGURED'}));process.exitCode=2;return;}
  const statuses=[];
  const fetcher=async(url,options)=>{const u=new URL(url);if(u.origin!=='https://generativelanguage.googleapis.com')throw Error('PROVIDER_DESTINATION_REJECTED');const r=await fetch(url,options);statuses.push(r.status);return r;};
  const service=require('/opt/astha/releases/current/api/services/operational-assistant.js');
  const result=await service.selectHighlights({intent:'stock',from:'2026-11-06',to:'2026-11-06'},{summary:{count:2},sources:[{ref:1,quantity:0,minimum:2},{ref:2,quantity:5,minimum:2}]},{env,fetcher});
  console.log(JSON.stringify({status:result.mode==='gemini'?'GEMINI_LIVE_PASSED':'GEMINI_LIVE_FALLBACK',providerStatuses:statuses,mode:result.mode,selectedReferences:result.refs,syntheticDataOnly:true}));
  if(result.mode!=='gemini')process.exitCode=2;
 }
}
if(require.main===module)main().catch(e=>{console.error('EXTERNAL_READINESS_FAILED',/^[A-Z0-9_]+$/.test(e.code||'')?e.code:'VALIDATION_FAILED');process.exitCode=1;});
