'use strict';
const { createHash } = require('node:crypto');
const personal = require('./personal-spaces');
const warehouse = require('./warehouse-context');
const { validateMaterialValues } = require('./material-values');
const fail = (message, status=400) => Object.assign(Error(message), {status});
function canonical(value) {
  if (value instanceof Date) return value.toISOString();
  if (Buffer.isBuffer(value)) return value.toJSON();
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, canonical(value[k])]));
  return value;
}
const hash = value => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
function materialTag(row) { const {sync_etag, ...data} = row; return hash(data); }
const withTag = row => ({...row, sync_etag: materialTag(row)});
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function operation(value) {
  if (!value || typeof value !== 'object' || !UUID.test(value.id||'') ||
      !['POST','PUT','DELETE'].includes(value.method) || typeof value.path !== 'string' ||
      !value.body || typeof value.body !== 'object' || Array.isArray(value.body) ||
      Buffer.byteLength(JSON.stringify(value)) > 1100000) throw fail('Operação de sincronização inválida.');
  const matches = [
    ['POST', /^\/api\/movements\/(entry|exit)$/, 'movement'],
    ['POST', /^\/api\/materials$/, 'material.create'],
    ['PUT', /^\/api\/materials\/([^/]{1,180})$/, 'material.update'],
    ['DELETE', /^\/api\/materials\/([^/]{1,180})$/, 'material.delete'],
    ['POST', /^\/api\/personal\/spaces$/, 'personal.create'],
    ['PUT', /^\/api\/personal\/spaces\/([1-9]\d*)$/, 'personal.save'],
    ['POST', /^\/api\/personal\/spaces\/([1-9]\d*)\/(archive|restore)$/, 'personal.archive'],
    ['POST', /^\/api\/personal\/spaces\/([1-9]\d*)\/belongings\/([a-zA-Z0-9_-]{1,64})\/move$/, 'personal.move']
  ];
  for (const [method, regex, kind] of matches) {
    const match = value.method === method && value.path.match(regex);
    if (match) return { id: value.id.toLowerCase(), method, path:value.path, body:value.body, kind, match,
      ...(value.expected_etag ? {expected_etag:value.expected_etag} : {}) };
  }
  throw fail('Esta ação exige conexão e não pode ser sincronizada offline.');
}
async function movement(db,user,op) {
  const b=op.body,qty=b.quantity,entry=op.match[1]==='entry';
  if (typeof b.code!=='string'||!b.code.trim()||b.code.length>100||typeof qty!=='number'||!Number.isFinite(qty)||qty<=0||qty>1e9||Math.abs(qty*1000-Math.round(qty*1000))>1e-6) throw fail('Código ou quantidade inválidos.');
  if (b.unit_price!==undefined) validateMaterialValues({unit_price:b.unit_price});
  for(const [key,max] of [['nf_number',50],['responsible',100],['reason',300],['notes',5000]]) if(b[key]!=null&&(typeof b[key]!=='string'||b[key].length>max)) throw fail('Dados de movimentação inválidos.');
  const [rows]=await db.execute('SELECT id,quantity FROM materials WHERE code=? AND org_id=? AND is_active=1 FOR UPDATE',[b.code,user.org_id]);
  if (!rows.length) throw fail('Material não encontrado.',404);
  const row=rows[0];
  if (!entry && Number(row.quantity)<qty) throw fail('Saldo insuficiente. Revise a movimentação antes de reenviar.',409);
  await db.execute(entry?'UPDATE materials SET quantity=quantity+? WHERE id=? AND org_id=?':'UPDATE materials SET quantity=quantity-? WHERE id=? AND org_id=?',[qty,row.id,user.org_id]);
  const [created]=await db.execute('INSERT INTO movements (material_id,type,quantity,nf_number,responsible,reason,notes,created_by) VALUES (?,?,?,?,?,?,?,?)',[row.id,entry?'entrada':'saida',qty,entry?(b.nf_number||null):null,b.responsible||user.email,b.reason||null,b.notes||null,user.id]);
  await db.execute('INSERT INTO movement_valuation (movement_id,warehouse_id,unit_price,org_id) SELECT ?,warehouse_id,COALESCE(?,unit_price),org_id FROM materials WHERE id=? AND org_id=?',[created.insertId,entry?(b.unit_price??null):null,row.id,user.org_id]);
  return {id:created.insertId,material_code:b.code,type:entry?'entrada':'saida',quantity:qty,new_stock:Number((Number(row.quantity)+(entry?qty:-qty)).toFixed(3))};
}
const materialFields = ['description','brand','model','sector','location','origin_country','quantity','min_qty','max_qty','unit_price','currency','unit','barcode','interchangeable','interchange_with','notes','machinery','warehouse_id'];
async function material(db,user,op) {
  const b=op.body;validateMaterialValues(b);
  if (Object.keys(b).some(k=>!materialFields.includes(k)&&k!=='code')) throw fail('Campos de material não suportados na sincronização.');
  const limits={description:300,brand:100,model:100,sector:100,location:50,origin_country:100,currency:5,unit:20,barcode:50,interchange_with:5000,notes:5000,machinery:200};
  for(const [key,max] of Object.entries(limits)) if(b[key]!=null&&(typeof b[key]!=='string'||b[key].length>max)) throw fail('Dados de material inválidos.');
  if(b.interchangeable!==undefined&&typeof b.interchangeable!=='boolean')throw fail('Intercambiabilidade inválida.');
  let code;
  if(op.kind==='material.create') {
    if(typeof b.description!=='string'||!b.description.trim())throw fail('Descrição obrigatória.');
    const [org]=await db.execute('SELECT id FROM organizations WHERE id=? FOR UPDATE',[user.org_id]);
    if(!org.length)throw fail('Organização não encontrada.',404);
    code=b.code;
    if(code!=null&&(typeof code!=='string'||!code.trim()||code.length>20))throw fail('Código inválido.');
    if(!code){const [last]=await db.execute("SELECT code FROM materials WHERE org_id=? AND code REGEXP '^MERB-[0-9]{8}$' ORDER BY code DESC LIMIT 1",[user.org_id]);code='MERB-'+String(last.length?Number(last[0].code.slice(5))+1:1).padStart(8,'0');}
    code=code.trim();
    const stock=await warehouse.warehouse(db,user.org_id,b.warehouse_id),location=await warehouse.validatePosition(db,user.org_id,stock.id,b.location);
    const data={description:b.description.trim(),...b,code,org_id:user.org_id,warehouse_id:stock.id,location,created_by:user.id};
    const columns=['code',...materialFields.filter(f=>data[f]!==undefined),'org_id','created_by'];
    await db.execute('INSERT INTO materials ('+columns.join(',')+') VALUES ('+columns.map(()=>'?').join(',')+')',columns.map(k=>k==='interchangeable'?(data[k]?1:0):data[k]));
  } else {
    try{code=decodeURIComponent(op.match[1]);}catch(_){throw fail('Código inválido.');}
    const [rows]=await db.execute('SELECT * FROM materials WHERE code=? AND org_id=? AND is_active=1 FOR UPDATE',[code,user.org_id]);
    if(!rows.length)throw fail('Material não encontrado.',404);
    if(typeof op.expected_etag!=='string'||op.expected_etag!==materialTag(rows[0]))throw fail('O material mudou no servidor. Recarregue e revise as alterações.',409);
    if(op.kind==='material.delete') {await db.execute('UPDATE materials SET is_active=0 WHERE id=? AND org_id=?',[rows[0].id,user.org_id]);return {message:'Material removido'};}
    if(b.code!==undefined&&b.code!==code)throw fail('O código do material não pode ser alterado.');
    const fields=materialFields.filter(k=>b[k]!==undefined);if(!fields.length)throw fail('Nenhum campo para atualizar.');
    if(fields.includes('location')||fields.includes('warehouse_id')){const stock=await warehouse.warehouse(db,user.org_id,b.warehouse_id??rows[0].warehouse_id);b.warehouse_id=stock.id;b.location=await warehouse.validatePosition(db,user.org_id,stock.id,b.location??rows[0].location);for(const k of ['warehouse_id','location'])if(!fields.includes(k))fields.push(k);}
    await db.execute('UPDATE materials SET '+fields.map(k=>k+'=?').join(',')+' WHERE id=? AND org_id=?',[...fields.map(k=>k==='interchangeable'?(b[k]?1:0):b[k]),rows[0].id,user.org_id]);
  }
  const [rows]=await db.execute('SELECT * FROM materials WHERE code=? AND org_id=?',[code,user.org_id]);return withTag(rows[0]);
}
async function execute(db,user,op) {
  if(op.kind==='movement')return movement(db,user,op);
  if(op.kind.startsWith('material.'))return material(db,user,op);
  // Reuse domain services on this transaction: their nested transaction calls do not commit the receipt separately.
  const view={execute:db.execute.bind(db),query:db.query.bind(db),beginTransaction:async()=>{},commit:async()=>{},rollback:async()=>{},release(){}};
  const facade={...view,getConnection:async()=>view};
  switch(op.kind){
    case 'personal.create':return personal.create(facade,user,op.body);
    case 'personal.save':return personal.save(facade,user,op.match[1],op.body);
    case 'personal.archive':return personal.archive(facade,user,op.match[1],op.body.version,op.match[2]==='archive');
    case 'personal.move':return personal.moveBelonging(facade,user,op.match[1],op.match[2],op.body);
    default:throw fail('Operação inválida.');
  }
}
async function apply(pool,user,value) {
  const op=operation(value),digest=hash({method:op.method,path:op.path,body:op.body,expected_etag:op.expected_etag??null});
  const db=await pool.getConnection();
  try{
    await db.beginTransaction();
    await db.execute('INSERT INTO mobile_sync_receipts (org_id,user_id,operation_id,request_hash) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE operation_id=operation_id',[user.org_id,user.id,op.id,digest]);
    const [rows]=await db.execute('SELECT request_hash,status_code,result_json FROM mobile_sync_receipts WHERE org_id=? AND user_id=? AND operation_id=? FOR UPDATE',[user.org_id,user.id,op.id]);
    if(rows[0].request_hash!==digest)throw fail('Identificador já utilizado por outra operação.',409);
    if(rows[0].status_code){await db.commit();return {status:rows[0].status_code,...JSON.parse(rows[0].result_json),replayed:true};}
    await db.query('SAVEPOINT mobile_operation');
    let status=200,result;
    try{result=await execute(db,user,op);}catch(e){
      if(![400,404,409,422].includes(e.status)&&e.code!=='ER_DUP_ENTRY')throw e;
      await db.query('ROLLBACK TO SAVEPOINT mobile_operation');status=e.code==='ER_DUP_ENTRY'?409:e.status;
      result={error:e.code==='ER_DUP_ENTRY'?'Código já cadastrado.':e.message};
    }
    const response={id:op.id,confirmed:status<400,result};
    await db.execute('UPDATE mobile_sync_receipts SET status_code=?,result_json=? WHERE org_id=? AND user_id=? AND operation_id=?',[status,JSON.stringify(response),user.org_id,user.id,op.id]);
    await db.commit();return {status,...response,replayed:false};
  }catch(e){await db.rollback().catch(()=>{});throw e;}finally{db.release();}
}
module.exports={operation,apply,withTag,materialTag};
