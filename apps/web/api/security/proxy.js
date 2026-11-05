'use strict';
module.exports=function configureProxy(app,env=process.env){
  if(env.TRUST_PROXY_LOOPBACK!=='true')return;
  if(!['127.0.0.1','::1'].includes(env.HOST))throw Error('PROXY_REQUIRES_LOOPBACK_BINDING');
  app.set('trust proxy','loopback');
};
