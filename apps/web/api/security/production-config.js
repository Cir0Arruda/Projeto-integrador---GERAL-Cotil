'use strict';
// Production SQL belongs exclusively to this VM. COTIL is retired.
function validateProduction(env=process.env){
  if(env.NODE_ENV!=='production'||env.HOST!=='127.0.0.1')throw Error('PRODUCTION_CONFIGURATION_REQUIRED');
  const topology=env.DB_TOPOLOGY;
  if(topology==='vps-local'){
    if(env.DB_HOST!=='127.0.0.1'||String(env.DB_PORT||3306)!=='3306'||env.DB_NAME!=='astha_raven_prod'||env.DB_SSL_REQUIRED!=='false')throw Error('VPS_DATABASE_CONFIGURATION_REQUIRED');
  }else throw Error('DATABASE_TOPOLOGY_INVALID');
  return topology;
}
module.exports={validateProduction};
