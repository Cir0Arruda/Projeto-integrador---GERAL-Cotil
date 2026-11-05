'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
process.env.JWT_SECRET=crypto.randomBytes(48).toString('hex');
const execute=async sql=>[sql.includes('SELECT workspace_type')?[{workspace_type:'corporate',setup_done:1}]:[]];
require.cache[require.resolve('../../api/database/connection')]={exports:{pool:{execute},testConnection:async()=>true,readWithRetry:execute}};
require.cache[require.resolve('../../api/middleware/auth')]={exports:(req,res,next)=>{
  req.user={id:1,org_id:'synthetic',role:req.headers['x-role']||'viewer'};next();
}};
const {app}=require('../../api/server');
const server=app.listen(0,'127.0.0.1');
after(()=>new Promise(resolve=>server.close(resolve)));
async function request(path,options={}) {
  if(!server.listening)await new Promise(resolve=>server.once('listening',resolve));
  return fetch('http://127.0.0.1:'+server.address().port+path,options);
}
test('plan features reach clients as correct UTF-8 Portuguese',async()=>{
  const response=await request('/api/plans');assert.equal(response.status,200);
  const plans=await response.json();
  assert.deepEqual(plans[0].features,['100 materiais','1 usuário','Dashboard básico']);
  assert.ok(plans[1].features.includes('5 usuários'));
});
test('user errors keep correctly encoded Portuguese accents over HTTP',async()=>{
  const denied=await request('/api/auth/users');assert.equal(denied.status,403);
  assert.equal((await denied.json()).error,'Sem permissão');
  const missing=await request('/api/auth/me');assert.equal(missing.status,404);
  assert.equal((await missing.json()).error,'Usuário não encontrado');
});
