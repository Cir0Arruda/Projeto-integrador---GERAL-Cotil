'use strict';
// Production SQL belongs exclusively to this VM. COTIL is retired.
function validateProduction(env=process.env){
  if(env.NODE_ENV!=='production'||env.HOST!=='127.0.0.1')throw Error('PRODUCTION_CONFIGURATION_REQUIRED');
  const topology=env.DB_TOPOLOGY;
  if(topology==='vps-local'){
    if(env.DB_HOST!=='127.0.0.1'||String(env.DB_PORT||3306)!=='3306'||env.DB_NAME!=='astha_raven_prod'||env.DB_SSL_REQUIRED!=='false')throw Error('VPS_DATABASE_CONFIGURATION_REQUIRED');
  }else throw Error('DATABASE_TOPOLOGY_INVALID');
  if(![undefined,'','false','true'].includes(env.MAIL_ENABLED))throw Error('MAIL_CONFIG_INVALID');
  if(env.MAIL_ENABLED==='true'){
    try{require('../services/transactional-mail').configuration(env);}catch(_){throw Error('MAIL_CONFIG_INVALID');}
  }
  return topology;
}
async function validateMailSchema(pool,env=process.env){
  if(env.MAIL_ENABLED!=='true')return false;
  // Read-only capability check. Never create/alter tables on application startup.
  try{await pool.execute('SELECT user_id,token,used,expires_at,created_at FROM password_resets LIMIT 0');}
  catch(_){throw Error('MAIL_SCHEMA_UNAVAILABLE');}
  return true;
}
module.exports={validateProduction,validateMailSchema};
