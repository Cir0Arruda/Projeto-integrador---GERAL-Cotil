'use strict';
function validateDatabaseDestination(env=process.env){
  const host=String(env.DB_HOST||'').toLowerCase().replace(/\.$/,'');
  if(env.DB_NAME==='cl205131'||host.endsWith('.cotil.unicamp.br')||host==='cotil.unicamp.br'||host==='143.106.241.4')throw Error('RETIRED_DATABASE_DESTINATION');
  if(env.NODE_ENV==='production')require('./production-config').validateProduction(env);
}
module.exports={validateDatabaseDestination};
