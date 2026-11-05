'use strict';
const router=require('express').Router(),{pool}=require('../database/connection');
const sync=require('../services/mobile-sync'),workspace=require('../middleware/workspaceMode');
router.use(require('../middleware/auth'),workspace.loadMode);
const group=require('../middleware/groupAccess')('wms',{action:'write'});
function checkGroup(req,res){return new Promise(resolve=>{let done=false;const finish=value=>{if(!done){done=true;res.off('finish',closed);resolve(value);}};const closed=()=>finish(false);res.once('finish',closed);let index=0;const next=()=>{if(index===group.length)return finish(true);Promise.resolve(group[index++](req,res,next)).catch(()=>{if(!res.headersSent)res.status(503).json({error:'Não foi possível verificar as permissões.'});finish(false);});};next();});}
router.post('/operations',async(req,res)=>{
  try{
    const op=sync.operation(req.body),personal=op.kind.startsWith('personal.');
    if((req.workspace.workspace_type==='personal')!==personal)return res.status(404).json({error:'Página não encontrada.'});
    if(!personal){const roles=op.kind==='material.update'||op.kind==='material.delete'?['superadmin','admin','manager']:['superadmin','admin','manager','operator'];if(!roles.includes(req.user.role))return res.status(403).json({error:'Sem permissão para sincronizar esta ação.'});if(!await checkGroup(req,res))return;}
    const {status,...body}=await sync.apply(pool,req.user,req.body);res.status(status).json(body);
  }catch(e){res.status(e.status||503).json({error:e.status?e.message:'Sincronização indisponível. A operação permanece pendente.'});}
});
module.exports=router;
