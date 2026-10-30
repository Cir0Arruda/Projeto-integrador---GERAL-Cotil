'use strict';
// Public origin only. Credentials and database addresses never belong in clients.
const DEFAULT_SERVER_URL='https://136.111.89.192';
function desktopServer(value,{args=[],env={},port='3000'}={}){
  const profiles=args.filter(a=>typeof a==='string'&&a.startsWith('--profile='));
  if(profiles.length>1||profiles.some(p=>!['--profile=local','--profile=backup','--profile=vps','--profile=principal'].includes(p))||env.ASTHA_ELECTRON_COTIL==='true')throw Error('DEPLOYMENT_PROFILE_INVALID');
  const local=profiles.some(p=>['--profile=local','--profile=backup'].includes(p));
  if(local){
    if(env.NODE_ENV==='production')throw Error('LOCAL_PROFILE_NOT_PRODUCTION');
    if(!['3000','3001'].includes(String(port)))throw Error('LOCAL_PORT_INVALID');
    return {url:'http://localhost:'+port,local:true};
  }
  const raw=value===undefined||value===''?DEFAULT_SERVER_URL:value;
  if(typeof raw!=='string'||raw.length>2048)throw Error('DEPLOYMENT_ORIGIN_INVALID');
  let target;try{target=new URL(raw);}catch{throw Error('DEPLOYMENT_ORIGIN_INVALID');}
  if(target.protocol!=='https:'||target.username||target.password||target.search||target.hash||target.pathname!=='/')throw Error('DEPLOYMENT_ORIGIN_INVALID');
  if(['clone.cotil.unicamp.br','143.106.241.4'].includes(target.hostname))throw Error('RETIRED_DATABASE_DESTINATION');
  return {url:target.origin,local:false};
}
module.exports={DEFAULT_SERVER_URL,desktopServer};
