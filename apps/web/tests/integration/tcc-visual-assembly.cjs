'use strict';
// Full HTTP application and MySQL, with disposable tenants and official GLB fixtures.
const assert=require('node:assert/strict');
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {startAuditApp}=require('./audit-app-sandbox.cjs');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
async function main(){
 const app=await startAuditApp({port:5183,fixtures:[{id:'tcc-visuala',type:'corporate',count:5},{id:'tcc-visualb',type:'corporate',count:1}]});
 const tokens={};let checks=0;
 try{
  const base='http://127.0.0.1:'+app.port;
  async function api(endpoint,{method='GET',body,actor='a',expected=200,binary=false,headers={}}={}){
   const response=await fetch(base+'/api'+endpoint,{method,headers:{'content-type':'application/json',...(tokens[actor]?{authorization:'Bearer '+tokens[actor]}:{}),...headers},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
   assert.equal(response.status,expected,endpoint+' '+JSON.stringify({status:response.status,expected}));checks++;
   if(binary)return{body:Buffer.from(await response.arrayBuffer()),headers:response.headers,status:response.status};
   return response.status===304?null:response.json();
  }
  const accounts={a:app.accounts.find(a=>a.org_id==='tcc-visuala'&&a.role==='admin'),b:app.accounts.find(a=>a.org_id==='tcc-visualb'),operator:app.accounts.find(a=>a.org_id==='tcc-visuala'&&a.role==='operator'),viewer:app.accounts.find(a=>a.org_id==='tcc-visuala'&&a.role==='viewer')};
  for(const [key,account]of Object.entries(accounts)){const result=await api('/auth/login',{method:'POST',body:{email:account.email,password:account.password},actor:'none'});tokens[key]=result.token;}
  const files={};
  for(const name of ['Box','BoxVertexColors','Avocado']){const bytes=await fs.readFile(path.join(__dirname,'../.runtime/tcc-3d-assets',name+'.glb'));files[name]={bytes,base64:bytes.toString('base64'),sha256:sha(bytes)};}
  assert(files.Avocado.bytes.length>8e6);
  const warehouse=await api('/warehouse/tabs',{method:'POST',body:{name:'Synthetic visual assembly stock'},expected:201});
  const material=await api('/materials',{method:'POST',body:{code:'TCC-GLB-PART',description:'Synthetic GLB assembly part',quantity:3,unit_price:9.99,warehouse_id:warehouse.id},expected:201});
  const read=await api('/materials/'+material.code);assert.match(read.sync_etag,/^[a-f0-9]{64}$/);
  const mother=await api('/eam/assets',{method:'POST',body:{asset_code:'GLB-MOTHER',name:'Synthetic machine assembly'},expected:201});
  const child=await api('/eam/assets',{method:'POST',body:{asset_code:'GLB-CHILD',name:'Synthetic drive module',parent_asset_id:mother.id},expected:201});
  await api('/eam/assets',{method:'POST',body:{asset_code:'GLB-CHILD-2',name:'Synthetic accessory',parent_asset_id:mother.id},expected:201});
  const foreign=await api('/eam/assets',{method:'POST',body:{asset_code:'GLB-FOREIGN',name:'Foreign synthetic machine'},actor:'b',expected:201});
  const module=await api(`/eam/assets/${mother.id}/modules`,{method:'POST',body:{code:'DRIVE',name:'Drive train',parent_module_id:null},expected:201});
  await api(`/eam/assets/${mother.id}/spares`,{method:'POST',body:{material_id:material.id,quantity:1,minimum_quantity:1,maximum_quantity:3},expected:201});
  const position=await api(`/eam/assets/${mother.id}/component-positions`,{method:'POST',body:{module_id:module.id,position_number:'P-001',name:'Assembly bearing',expected_item_id:material.id,quantity_required:1},expected:201});
  await api(`/eam/assets/${foreign.id}/component-positions`,{method:'POST',body:{position_number:'ILLEGAL',name:'Foreign item linkage',expected_item_id:material.id,quantity_required:1},actor:'b',expected:404});
  const ownVisual=await api(`/eam/assets/${mother.id}/visuals`,{method:'POST',body:{type:'3d_model',title:'Official Box fixture',filename:'Box.glb',file_data:files.Box.base64,module_id:module.id},expected:201});
  const childVisual=await api(`/eam/assets/${child.id}/visuals`,{method:'POST',body:{type:'3d_model',title:'Official BoxVertexColors fixture',filename:'BoxVertexColors.glb',file_data:files.BoxVertexColors.base64},expected:201});
  const materialFile=await api(`/materials/${material.code}/files`,{method:'POST',body:{category:'product_3d',filename:'Avocado.glb',description:'Official Avocado validation fixture, not industrial equipment',file_data:files.Avocado.base64},expected:201});
  const avocado=await api(`/materials/${material.code}/files/${materialFile.id}/data`,{binary:true});assert.equal(sha(avocado.body),files.Avocado.sha256);assert.ok(avocado.headers.get('etag'));
  const cached=await api(`/materials/${material.code}/files/${materialFile.id}/data`,{expected:304,binary:true,headers:{'if-none-match':avocado.headers.get('etag'),'cache-control':'max-age=0'}});assert.equal(cached.body.length,0);
  await api(`/materials/${material.code}/files/${materialFile.id}/data`,{actor:'b',expected:404,headers:{'if-none-match':avocado.headers.get('etag')}});
  await api(`/materials/${material.code}/files`,{method:'POST',body:{category:'product_3d',filename:'Box.glb',file_data:files.Box.base64},actor:'operator',expected:403});
  const box=await api(`/eam/assets/${mother.id}/visuals/${ownVisual.id}/data`,{binary:true});assert.equal(sha(box.body),files.Box.sha256);
  await api(`/eam/assets/${mother.id}/visuals/${ownVisual.id}/data`,{actor:'b',expected:404});
  await api(`/eam/assets/${child.id}/visuals/${ownVisual.id}/data`,{expected:404});
  const candidates=await api(`/eam/assets/${mother.id}/assembly-candidates`);assert(candidates.some(c=>c.source_type==='child_visual'&&c.source_id===childVisual.id));assert(candidates.some(c=>c.source_type==='material_file'&&c.source_id===materialFile.id));
  const placement={module_id:module.id,component_position_id:position.id,tx:1,ty:2,tz:3,rx:.1,ry:.2,rz:.3,scale_factor:1.5,explode_dx:4,explode_dy:5,explode_dz:6,anchor_x:0,anchor_y:0,anchor_z:0};
  await api(`/eam/assets/${mother.id}/assembly-parts`,{method:'POST',body:{...placement,visual_id:ownVisual.id},expected:201});
  await api(`/eam/assets/${mother.id}/assembly-sources`,{method:'POST',body:{...placement,source_type:'child_visual',source_id:childVisual.id},expected:201});
  await api(`/eam/assets/${mother.id}/assembly-sources`,{method:'POST',body:{...placement,source_type:'material_file',source_id:materialFile.id},expected:201});
  await api(`/eam/assets/${mother.id}/spatial`,{method:'PATCH',body:{x:5,y:0,z:7,rotation:45,level:'Piso 1'}});
  const assembly=await api(`/eam/assets/${mother.id}/assembly-parts`);assert.equal(assembly.length,3);for(const row of assembly){assert.equal(Number(row.tx),1);assert.equal(Number(row.scale_factor),1.5);assert.equal(Number(row.explode_dz),6);assert.equal(Number(row.component_position_id),position.id);}
  const twin=await api(`/eam/assets/${mother.id}/digital-twin`);assert.equal(Number(twin.asset.spatial_x),5);assert.equal(twin.positions[0].expected_item_code,material.code);assert.equal(Number(twin.positions[0].expected_item_stock),3);
  await api(`/eam/assets/${mother.id}/assembly-parts`,{actor:'b',expected:404});
  await api(`/eam/assets/${mother.id}/assembly-parts`,{method:'POST',body:{visual_id:ownVisual.id},actor:'b',expected:404});
  await api(`/eam/assets/${mother.id}/assembly-sources`,{method:'POST',body:{source_type:'child_visual',source_id:ownVisual.id},expected:404});
  await api(`/eam/assets/${mother.id}/assembly-parts`,{method:'POST',body:{visual_id:ownVisual.id,scale_factor:0},expected:400});
  await api(`/eam/assets/${mother.id}/assembly-parts`,{method:'POST',body:{visual_id:ownVisual.id,anchor_x:1},expected:400});
  await api(`/eam/assets/${mother.id}/assembly-parts`,{method:'POST',body:{visual_id:ownVisual.id},actor:'viewer',expected:403});
  const before=await api(`/eam/assets/${mother.id}/snapshots`,{method:'POST',body:{label:'Before calibration',kind:'as_designed'},expected:201});
  await api(`/eam/assets/${mother.id}/assembly-parts`,{method:'POST',body:{...placement,visual_id:ownVisual.id,anchor_x:.5,anchor_y:.25,anchor_z:.75},expected:201});
  const after=await api(`/eam/assets/${mother.id}/snapshots`,{method:'POST',body:{label:'After anchor calibration',kind:'as_built'},expected:201});
  const comparison=await api(`/eam/assets/${mother.id}/snapshot-comparison?left=${before.id}&right=${after.id}`);
  assert(comparison.changes.some(change=>change.section==='parts'&&Number(change.before.anchor_x)===0&&Number(change.after.anchor_x)===.5),'Equipment revisions must preserve anchor calibration');
  const revision=await api(`/eam/assets/${mother.id}/revisions`,{method:'POST',body:{revision_code:'A'},expected:201});
  await api(`/eam/assets/${mother.id}/revisions/${revision.id}/status`,{method:'PATCH',body:{status:'active'},expected:409});
  await api(`/eam/assets/${mother.id}/revisions/${revision.id}/status`,{method:'PATCH',body:{status:'under_review'},actor:'operator',expected:403});
  for(const status of ['under_review','approved','active'])await api(`/eam/assets/${mother.id}/revisions/${revision.id}/status`,{method:'PATCH',body:{status}});
  const pdf=Buffer.from('%PDF-1.4\n% Synthetic test document\n%%EOF').toString('base64');
  const document=await api(`/eam/assets/${mother.id}/documents`,{method:'POST',body:{document_number:'TCC-MANUAL',title:'Synthetic machine manual',document_type:'manual',revision_code:'A',filename:'manual.pdf',file_data:pdf},expected:201});
  const docRevision=await api(`/eam/documents/${document.id}/revisions`,{method:'POST',body:{revision_code:'B',filename:'manual-b.pdf',file_data:pdf},expected:201});
  for(const status of ['under_review','approved','active'])await api(`/eam/documents/${document.id}/revisions/${docRevision.id}/status`,{method:'PATCH',body:{status}});
  const documents=await api(`/eam/assets/${mother.id}/documents`);assert.equal(documents[0].revision_code,'B');
  const doc=await api(`/eam/documents/${document.id}/revisions/${docRevision.id}/data`,{binary:true});assert.equal(sha(doc.body),sha(Buffer.from(pdf,'base64')));
  await api(`/eam/documents/${document.id}/revisions/${docRevision.id}/data`,{actor:'b',expected:404});
  await api(`/eam/assets/${mother.id}/snapshots/${after.id}`,{method:'PATCH',body:{status:'approved',note:'Synthetic acceptance verification'}});
  const saved=await api(`/eam/assets/${mother.id}/assembly-parts`);assert.equal(Number(saved.find(p=>p.source_type==='equipment_visual').anchor_x),.5);
  const [[persisted]]=await app.admin.execute('SELECT COUNT(*) AS n FROM equipment_assembly_external_parts WHERE equipment_id=?',[mother.id]);assert.equal(Number(persisted.n),2);
  console.log(JSON.stringify({status:'TCC_VISUAL_ASSEMBLY_PASSED',httpChecks:checks,models:Object.fromEntries(Object.entries(files).map(([name,f])=>[name,{bytes:f.bytes.length,sha256:f.sha256}])),assemblyParts:3,materialsViaApi:true,fullMiddleware:true,anchorRevision:true,conditionalEtag:true,tenantIsolation:true,persistence:true}));
 }finally{await app.close();}
}
if(require.main===module)main().catch(error=>{console.error('TCC_VISUAL_ASSEMBLY_FAILED',error.code||'VALIDATION_FAILED',error.code==='ERR_ASSERTION'?error.message:'');process.exitCode=1;});
