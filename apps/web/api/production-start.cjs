'use strict';
// Dedicated VM entrypoint: no Windows profile and no automatic database fallback.
async function main(){
  require('./security/production-config').validateProduction();
  const {pool}=require('./database/connection');
  try{
    await pool.execute('SELECT 1');
    await pool.execute('SELECT operation_id FROM mobile_sync_receipts LIMIT 0');
    const [indexes]=await pool.execute("SELECT INDEX_NAME,GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns_list FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='materials' AND NON_UNIQUE=0 GROUP BY INDEX_NAME");
    if(!indexes.some(i=>i.columns_list==='org_id,code')||indexes.some(i=>i.columns_list==='code'))throw Error('MATERIAL_SCOPE_MIGRATION_REQUIRED');
    await require('./security/production-config').validateMailSchema(pool);
    await require('./server').startServer();
  }catch(e){await pool.end().catch(()=>{});throw e;}
}
if(require.main===module)main().catch(e=>{console.error('PRODUCTION_START_BLOCKED',/^[A-Z_]+$/.test(e.code||e.message)?e.code||e.message:'DEPENDENCY_UNAVAILABLE');process.exitCode=1;});
module.exports={main};
