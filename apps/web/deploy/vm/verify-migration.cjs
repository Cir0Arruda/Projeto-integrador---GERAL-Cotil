'use strict';
// Read-only destination comparison. Receives the verified source snapshot over SSH stdin.
const crypto=require('node:crypto'),fs=require('node:fs/promises'),{createRequire}=require('node:module');
const quote=n=>{if(!/^[a-zA-Z0-9_]{1,64}$/.test(n))throw Error('AUDIT_IDENTIFIER_INVALID');return '`'+n+'`';};
function canonical(v){if(v===null||typeof v!=='object')return v;if(Buffer.isBuffer(v))return {type:'Buffer',data:[...v]};if(Array.isArray(v))return v.map(canonical);return Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])]));}
function hashRow(row,columns){return crypto.createHash('sha256').update(JSON.stringify(columns.map(c=>{
 const v=row[c.COLUMN_NAME];if(v===null||v===undefined)return null;
 if(c.DATA_TYPE==='json'){const parsed=typeof v==='string'?JSON.parse(v):v;return canonical(parsed);}
 if(['bit','binary','varbinary','tinyblob','blob','mediumblob','longblob'].includes(c.DATA_TYPE))return Buffer.isBuffer(v)?v.toString('base64'):v?.type==='Buffer'?Buffer.from(v.data).toString('base64'):v;
 return String(v);
}))).digest('hex');}
async function main(){
 if(process.getuid?.()!==0)throw Error('ADMIN_REQUIRED');
 const load=createRequire('/opt/astha/releases/current/api/package.json');
 let input='',size=0;for await(const chunk of process.stdin){size+=chunk.length;if(size>64*1024*1024)throw Error('AUDIT_LIMIT');input+=chunk;}
 const snapshot=JSON.parse(input);if(snapshot.manifest?.timestampTimeZone!=='+00:00'||snapshot.tables.length!==snapshot.manifest.tables.length)throw Error('UTC_VERIFIED_SOURCE_REQUIRED');
 const db=await load('mysql2/promise').createConnection({socketPath:'/run/mysqld/mysqld.sock',user:'root',database:'astha_raven_prod',dateStrings:true,supportBigNumbers:true,bigNumberStrings:true,multipleStatements:false});
 const changes=new Set(['sessions','password_resets','mobile_sync_receipts']);
 try{
  await db.query("SET SESSION time_zone='+00:00'");await db.query('START TRANSACTION WITH CONSISTENT SNAPSHOT, READ ONLY');
  const report={checkedAt:new Date().toISOString(),sourceTables:snapshot.tables.length,sourceRows:0,tables:[],foreignKeyOrphans:0,missingColumns:0,unexplainedMissingRows:0};
  for(const table of snapshot.tables){
   quote(table.name);report.sourceRows+=table.rows.length;
   const expected=snapshot.manifest.tables.find(t=>t.name===table.name),digest=crypto.createHash('sha256');for(const row of table.rows)digest.update(JSON.stringify(row)+'\n');if(expected.rows!==table.rows.length||digest.digest('hex')!==expected.sha256)throw Error('SOURCE_HASH_INVALID');
   const [columns]=await db.execute('SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=?',[table.name]);
   const missing=table.columns.filter(c=>!columns.some(k=>k.COLUMN_NAME===c.COLUMN_NAME));report.missingColumns+=missing.length;
   if(missing.length){report.tables.push({name:table.name,status:'missing_columns',count:missing.length});continue;}
   const projection=table.columns.map(c=>['date','datetime','timestamp','time'].includes(c.DATA_TYPE)?'CAST('+quote(c.COLUMN_NAME)+' AS CHAR) AS '+quote(c.COLUMN_NAME):quote(c.COLUMN_NAME)).join(',');
   const [rows]=await db.query('SELECT '+projection+' FROM '+quote(table.name));
   const counts=new Map();for(const row of rows){const h=hashRow(row,table.columns);counts.set(h,(counts.get(h)||0)+1);}
   let absent=0;for(const row of table.rows){const h=hashRow(row,table.columns),n=counts.get(h)||0;if(n)counts.set(h,n-1);else absent++;}
   const added=[...counts.values()].reduce((n,x)=>n+x,0),expectedChange=changes.has(table.name);
   if(!expectedChange)report.unexplainedMissingRows+=absent;
   report.tables.push({name:table.name,sourceRows:table.rows.length,targetRows:rows.length,missingOrChanged:absent,newOrChanged:added,status:expectedChange?'ephemeral_origin_state_reset':absent?'review_required':added?'source_preserved_with_additions':'exact'});
  }
  const [keys]=await db.execute('SELECT TABLE_NAME,CONSTRAINT_NAME,COLUMN_NAME,REFERENCED_TABLE_SCHEMA,REFERENCED_TABLE_NAME,REFERENCED_COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() AND REFERENCED_TABLE_NAME IS NOT NULL ORDER BY TABLE_NAME,CONSTRAINT_NAME,ORDINAL_POSITION');
  const groups=new Map();for(const k of keys){if(k.REFERENCED_TABLE_SCHEMA!=='astha_raven_prod')throw Error('CROSS_SCHEMA_REFERENCE');const id=k.TABLE_NAME+':'+k.CONSTRAINT_NAME;if(!groups.has(id))groups.set(id,[]);groups.get(id).push(k);}
  for(const cs of groups.values()){const first=cs[0],join=cs.map(c=>'p.'+quote(c.REFERENCED_COLUMN_NAME)+'=c.'+quote(c.COLUMN_NAME)).join(' AND '),present=cs.map(c=>'c.'+quote(c.COLUMN_NAME)+' IS NOT NULL').join(' AND ');const [[r]]=await db.query('SELECT COUNT(*) AS n FROM '+quote(first.TABLE_NAME)+' c LEFT JOIN '+quote(first.REFERENCED_TABLE_NAME)+' p ON '+join+' WHERE '+present+' AND p.'+quote(first.REFERENCED_COLUMN_NAME)+' IS NULL');report.foreignKeyOrphans+=Number(r.n);}
  await db.rollback();
  const env=load('dotenv').parse(await fs.readFile('/etc/astha/runtime.env'));report.configuration={topology:env.DB_TOPOLOGY,host:env.DB_HOST,database:env.DB_NAME,apiLoopback:env.HOST==='127.0.0.1',noCotil:env.DB_NAME!=='cl205131'&&!String(env.DB_HOST).includes('cotil')};
  report.passed=!report.missingColumns&&!report.unexplainedMissingRows&&!report.foreignKeyOrphans&&report.configuration.noCotil;
  console.log(JSON.stringify(report));if(!report.passed)process.exitCode=1;
 }finally{await db.end();}
}
if(require.main===module)main().catch(e=>{console.error('MIGRATION_AUDIT_FAILED',e.code||(/^[A-Z_]+$/.test(e.message)?e.message:'REVIEW_REQUIRED'));process.exitCode=1;});
module.exports={hashRow,quote};
