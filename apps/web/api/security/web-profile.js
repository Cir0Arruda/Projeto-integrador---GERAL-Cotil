'use strict';
const fs=require('node:fs/promises');
// The installed VPS is the default. Recovery is always an explicit local choice.
async function select({requested=process.env.ASTHA_WEB_PROFILE,production=process.env.NODE_ENV==='production',platform=process.platform,local=require('./local-profile'),exists=async file=>{try{await fs.access(file);return true;}catch(error){if(error.code==='ENOENT')return false;throw error;}}}={}){
 if(requested!==undefined&&!['local','principal','vps','backup'].includes(requested))throw Error('WEB_PROFILE_INVALID');
 if(production){if(['local','backup'].includes(requested))throw Error('LOCAL_PROFILE_NOT_PRODUCTION');return {name:'principal',env:{}};}
 if(!['local','backup'].includes(requested))return {name:'vps',env:{},url:require('./client-deployment').desktopServer(process.env.ASTHA_SERVER_URL).url};
 if(platform!=='win32')throw Error('WINDOWS_PROFILE_REQUIRED');
 if(!await exists(await local.profilePath()))throw Error('LOCAL_PROFILE_MISSING');
 // Decryption/validation errors are fatal; never fall back to a different database.
 return {name:'local',env:await local.load()};
}
module.exports={select};
