'use strict';
// Uses a new disposable MySQL process; never the app's configured database.
const {startSandbox}=require('./analytics-sandbox');
const assert=require('node:assert/strict'),{randomBytes}=require('node:crypto');
const express=require('../../api/node_modules/express'),bcrypt=require('../../api/node_modules/bcryptjs');
async function main(){
 const sandbox=await startSandbox();let server;
 try{
  const {admin,pool}=sandbox;
  await require('../../api/database/migrate_material_code_scope').migrateMaterialCodeScope(admin);
  await require('../../api/database/migrate_material_code_scope').migrateMaterialCodeScope(admin);
  await admin.query('CREATE TABLE movement_valuation (movement_id INT PRIMARY KEY,warehouse_id INT NULL,unit_price DECIMAL(18,4) NOT NULL,org_id VARCHAR(50) NOT NULL) ENGINE=InnoDB');
  await admin.query('GRANT SELECT,INSERT ON '+sandbox.db+".movement_valuation TO 'astha_test'@'127.0.0.1'");
  const tokens={};
  for(const org of ['qa-stock-a','qa-stock-b']){
   await pool.execute('INSERT INTO organizations(id,name,plan) VALUES(?,?,?)',[org,'Organização sintética','Enterprise']);
   const [created]=await pool.execute('INSERT INTO users(name,email,password_hash,role,org_id,is_active) VALUES(?,?,?,?,?,1)',['QA sintético',org+'@example.invalid',await bcrypt.hash(randomBytes(32).toString('hex'),10),'admin',org]);
   const {signToken,expiresAt}=require('../../api/security/tokens');const token=signToken({id:created.insertId,org_id:org});
   await pool.execute('INSERT INTO sessions(user_id,token,expires_at) VALUES(?,?,?)',[created.insertId,token,expiresAt(token)]);tokens[org]=token;
  }
  const [material]=await pool.execute('INSERT INTO materials(code,description,quantity,unit_price,org_id,is_active) VALUES(?,?,?,?,?,1)',['QA-STOCK-1','Material sintético',1.125,10,'qa-stock-a']);
  await pool.execute('INSERT INTO materials(code,description,quantity,unit_price,org_id,is_active) VALUES(?,?,?,?,?,1)',['QA-STOCK-1','Outro material sintético',2,10,'qa-stock-b']);
  await assert.rejects(pool.execute('INSERT INTO materials(code,description,org_id) VALUES(?,?,?)',['QA-STOCK-1','Duplicado','qa-stock-a']),error=>error.code==='ER_DUP_ENTRY');
  console.log('PASS SKU por organização e migração repetível');
  const app=express();app.use(express.json());app.use('/api/movements',require('../../api/routes/movements'));
  server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});const base='http://127.0.0.1:'+server.address().port;
  async function send(action,body,org='qa-stock-a'){const response=await fetch(base+'/api/movements/'+action,{method:'POST',headers:{Authorization:'Bearer '+tokens[org],'Content-Type':'application/json'},body:JSON.stringify({code:'QA-STOCK-1',...body}),signal:AbortSignal.timeout(10000)});return{status:response.status,data:await response.json()};}
  const entry=await send('entry',{quantity:1.125,unit_price:8.75});assert.equal(entry.status,201);assert.equal(entry.data.new_stock,2.25);
  const [[author]]=await pool.execute('SELECT m.created_by,u.org_id FROM movements m JOIN users u ON u.id=m.created_by WHERE m.id=?',[entry.data.id]);assert.equal(author.org_id,'qa-stock-a');assert.ok(author.created_by);console.log('PASS autoria da movimentação vinculada à sessão');
  const [[valuation]]=await pool.execute('SELECT unit_price FROM movement_valuation WHERE movement_id=?',[entry.data.id]);assert.equal(Number(valuation.unit_price),8.75);console.log('PASS entrada fracionária e preço de compra preservados no MySQL');
  const exit=await send('exit',{quantity:.125});assert.equal(exit.status,201);assert.equal(exit.data.new_stock,2.125);
  const parallel=await Promise.all([send('exit',{quantity:2}),send('exit',{quantity:2})]);assert.deepEqual(parallel.map(r=>r.status).sort(),[201,400]);
  const [[stock]]=await pool.execute('SELECT quantity FROM materials WHERE id=?',[material.insertId]);assert.equal(Number(stock.quantity),.125);console.log('PASS saídas concorrentes não deixam estoque negativo nem perdem as frações');
  assert.equal((await send('entry',{quantity:1},'qa-stock-b')).status,201);const [[afterForeign]]=await pool.execute('SELECT quantity FROM materials WHERE id=?',[material.insertId]);assert.equal(Number(afterForeign.quantity),.125);console.log('PASS SKU igual de outra organização não altera o material original');
  await pool.execute('UPDATE materials SET is_active=0 WHERE id=?',[material.insertId]);for(const action of ['entry','exit'])assert.equal((await send(action,{quantity:.125})).status,404);console.log('PASS material excluído não aceita novas movimentações');
 }finally{if(server){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}await sandbox.close();}
}
main().catch(error=>{console.error('STOCK_INTEGRATION_FAILED:'+error.message);process.exitCode=1;});
