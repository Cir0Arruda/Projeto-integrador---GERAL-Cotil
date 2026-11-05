'use strict';
// Produces reviewable SQL for an administrator; does not execute DDL or grants.
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os');
async function main(){
  const env=await require('../security/local-profile').load();
  const connection=await require('../node_modules/mysql2/promise').createConnection({host:env.DB_HOST,port:Number(env.DB_PORT),database:env.DB_NAME,user:env.DB_USER,password:env.DB_PASSWORD,multipleStatements:false,flags:'-LOCAL_FILES'});
  try{
    const [[row]]=await connection.query('SELECT CURRENT_USER() AS account');
    if(!/^astha_lab_web@(localhost|127\.0\.0\.1)$/.test(row.account))throw Error('UNEXPECTED_RUNTIME_ACCOUNT');
    const [user,host]=row.account.split('@');
    const sql='-- Additive migration for the local laboratory only. Run using an administrator.\n-- No DROP, DELETE, data reset, account creation or remote connection.\nUSE `astha_raven_lab`;\n'+require('../database/migrate_mobile_sync').schema+';\nGRANT SELECT,INSERT,UPDATE,DELETE ON `astha_raven_lab`.`mobile_sync_receipts` TO \''+user+'\'@\''+host+'\';\n';
    const file=path.join(os.homedir(),'Downloads','ASTHA_ATIVAR_SYNC_LOCAL.sql');
    await fs.writeFile(file,sql,{flag:'wx',encoding:'utf8'});
    console.log(JSON.stringify({file,executedDDL:false}));
  }finally{await connection.end();}
}
if(require.main===module)main().catch(e=>{console.error('MIGRATION_PREPARATION_FAILED',e.code||e.message);process.exitCode=1;});
module.exports={main};
