'use strict';
// Disposable lab transaction: no real records are changed or sent to a provider.
const assert=require('node:assert/strict'),crypto=require('node:crypto');
(async()=>{
 const profile=await require('../security/local-profile').load();if(profile.DB_NAME!=='astha_raven_lab')throw Error('Lab required');Object.assign(process.env,profile);
 const {pool}=require('../database/connection'),assistant=require('../services/contextual-assistant'),{insights}=require('../services/stock-insights');
 const db=await pool.getConnection(),org='qa_values_'+crypto.randomBytes(6).toString('hex'),other=org+'_other',user={id:1,org_id:org,role:'admin'};
 const insert=async(sql,params)=>(await db.execute(sql,params))[0].insertId;
 try{
  await db.beginTransaction();for(const id of [org,other])await insert('INSERT INTO organizations (id,name) VALUES (?,?)',[id,'Disposable values QA']);
  const stocks=[];
  for(const owner of [org,org,other]){const layout=await insert("INSERT INTO warehouse_layout (org_id,name,room_w,room_h,door_x,door_y,door_w,blueprint_data) VALUES (?,?,720,480,620,480,100,'{}')",[owner,'PRIVATE MAP']);const warehouse=await insert('INSERT INTO warehouses (org_id,name) VALUES (?,?)',[owner,'PRIVATE STOCK']);await insert('INSERT INTO warehouse_context (warehouse_id,org_id,layout_id) VALUES (?,?,?)',[warehouse,owner,layout]);stocks.push(warehouse);}
  const material=await insert("INSERT INTO materials (org_id,warehouse_id,code,description,brand,location,quantity,min_qty,unit_price,currency,unit,is_active) VALUES (?,?,?,?,?,?,8,9,6875,'BRL','UN',1)",[org,stocks[0],'QA-MOTOR','PRIVATE MOTOR NAME','PRIVATE BRAND','PRIVATE LOCATION']);
  const zero=await insert("INSERT INTO materials (org_id,warehouse_id,code,description,quantity,min_qty,unit_price,currency,is_active) VALUES (?,?,?,?,10,2,0,'BRL',1)",[org,stocks[0],'QA-ZERO','PRIVATE ZERO ITEM']);
  const foreign=await insert("INSERT INTO materials (org_id,warehouse_id,code,description,quantity,min_qty,unit_price,currency,is_active) VALUES (?,?,?,?,1,2,999999,'BRL',1)",[other,stocks[2],'QA-FOREIGN','FOREIGN PRIVATE']);
  const usd=await insert("INSERT INTO materials (org_id,warehouse_id,code,description,quantity,min_qty,unit_price,currency,is_active) VALUES (?,?,?,?,2,3,10,'USD',1)",[org,stocks[1],'QA-USD','PRIVATE USD ITEM']);
  const first=await insert("INSERT INTO movements (material_id,type,quantity,created_at) VALUES (?,'entrada',2,'2026-10-06 10:00:00')",[material]);
  const second=await insert("INSERT INTO movements (material_id,type,quantity,created_at) VALUES (?,'entrada',2,'2026-10-14 10:00:00')",[zero]);
  const exit=await insert("INSERT INTO movements (material_id,type,quantity,created_at) VALUES (?,'saida',1,'2026-10-14 11:00:00')",[material]);
  await insert('INSERT INTO movement_valuation (movement_id,warehouse_id,unit_price,org_id) VALUES (?,?,?,?)',[first,stocks[0],6875,org]);
  await insert('INSERT INTO movement_valuation (movement_id,warehouse_id,unit_price,org_id) VALUES (?,?,?,?)',[second,stocks[0],0,org]);
  const state={refs:new Map(),next:1},body={viewContext:{from:'2026-09-15',to:'2026-10-14',warehouseIds:[stocks[0]]}};
  const movements=await assistant.readTool(db,user,{module:'movements',status:'entrada'},state,body);
  assert.equal(movements.summary.total,2);assert.equal(movements.summary.types.entrada.valueByCurrency[0].value,13750);assert.equal(movements.summary.estimated,0);assert.equal(movements.to,'2026-10-14');
  const panel=await insights(db,org,{from:body.viewContext.from,to:body.viewContext.to,warehouses:String(stocks[0])});
  assert.equal(panel.series.filter(r=>r.type==='entrada').reduce((sum,r)=>sum+Number(r.value),0),movements.summary.types.entrada.valueByCurrency[0].value);
  if(process.argv.includes('--gemini')){
   let requests=0;
   const options={onFallback:error=>console.log('Gemini fallback:',error.name,['Invalid function calls','Mixed final response','Invalid final answer','Tool limit','No grounded response','Invalid provider response','Provider unavailable'].includes(error.message)?error.message:''),fetcher:async(url,request)=>{assert.ok(!request.body.includes('PRIVATE'));assert.ok(!request.body.includes(org));requests++;const response=await fetch(url,request);if(!response.ok)console.log('Gemini status:',response.status);else{const data=await response.clone().json();console.log('Gemini calls:',data.candidates?.[0]?.content?.parts?.filter(p=>p.functionCall).map(p=>({name:p.functionCall.name,module:p.functionCall.args?.module})));}return response;}};
   const answer=await assistant.answer(db,user,{question:'Qual o valor das entradas no período?',...body},options);
   try{assert.equal(answer.mode,'gemini');assert.match(answer.message,/13[.\s]?750(?:,00)?/);assert.equal(answer.queries[0].to,body.viewContext.to);console.log('Live Gemini values: R$ 13,750 in entries, panel dates and anonymous payloads passed. Requests:',requests);}finally{assistant.clear(user,answer.conversationId);}
  }
  const stock=await assistant.readTool(db,user,{module:'stock'},state,body);assert.equal(stock.summary.valueByCurrency[0].value,55000);assert.equal(Number(panel.summary.stock_value),stock.summary.valueByCurrency[0].value);assert.equal(stock.sources.find(s=>s.id===zero).unitPrice,0);
  assert.equal(stock.sources.find(s=>s.id===material).name,'PRIVATE MOTOR NAME');assert.equal(stock.sources.find(s=>s.id===material).brand,'PRIVATE BRAND');
  assert.ok(!JSON.stringify(assistant.anonymous(stock)).includes('PRIVATE'));assert.ok(!JSON.stringify(assistant.anonymous(movements)).includes('QA-MOTOR'));
  const multiple=await assistant.readTool(db,user,{module:'stock'},state,{viewContext:{...body.viewContext,warehouseIds:[stocks[0],stocks[1]]}});assert.equal(multiple.summary.valueByCurrency.length,2);assert.equal(multiple.summary.valueByCurrency.find(v=>v.currency==='USD').value,20);
  await assert.rejects(assistant.readTool(db,user,{module:'stock'},state,{viewContext:{...body.viewContext,warehouseIds:[stocks[2]]}}),{status:404});
  await db.execute('UPDATE materials SET unit_price=9000,warehouse_id=? WHERE id=? AND org_id=?',[stocks[1],material,org]);
  const history=await assistant.readTool(db,user,{module:'movements'},state,body);assert.equal(history.sources.find(s=>s.id===first).unitPrice,6875);assert.equal(history.sources.find(s=>s.id===first).movementValue,13750);
  const estimate=await assistant.readTool(db,user,{module:'movements',status:'saida'},state,{viewContext:{...body.viewContext,warehouseIds:[stocks[1]]}});assert.equal(estimate.sources.find(s=>s.id===exit).movementValue,9000);assert.equal(estimate.sources.find(s=>s.id===exit).valuation,'estimated_current_price');
  // More than one page: sums must include every matching row, not just the displayed page.
  for(let i=0;i<22;i++)await insert("INSERT INTO materials (org_id,warehouse_id,code,description,quantity,min_qty,unit_price,currency,is_active) VALUES (?,?,?,?,1,0,0.1,'BRL',1)",[org,stocks[0],'QA-PAGE-'+i,'PRIVATE PAGE ITEM']);
  const paged=await assistant.readTool(db,user,{module:'stock',search:'QA-PAGE',sort:'value_desc'},state,body);assert.equal(paged.summary.total,22);assert.equal(paged.sources.length,20);assert.equal(paged.summary.valueByCurrency[0].value,2.2);assert.equal(paged.limited,true);
  const fallback=await assistant.answer(db,user,{question:'Qual o valor das entradas no período?',...body},{env:{}});assert.match(fallback.message,/13\.750,00/);assert.ok(!fallback.sources.some(s=>s.id===foreign));assistant.clear(user,fallback.conversationId);
  console.log('Values/MySQL: panel parity (R$ 13,750 entries), current stock, zero prices, saved historical prices after transfer, estimates, currency separation, multi-stock authorization, all-page totals, basic fields and provider privacy passed.');
 }finally{await db.rollback();db.release();await pool.end();}
})().catch(error=>{console.error('Values QA failed:',error.code||error.name,error.name==='AssertionError'?error.message:'');process.exitCode=1;});
