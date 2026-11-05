'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),express=require('../../api/node_modules/express');
const {validateMaterialValues}=require('../../api/services/material-values');
let failConnection=false,deleted=false,connections=0,calls=[],commits=0,rollbacks=0,releases=0;
const connection={beginTransaction:async()=>{},commit:async()=>{commits++;},rollback:async()=>{rollbacks++;},release:()=>{releases++;},execute:async(sql,args)=>{
 calls.push({sql,args});if(sql.startsWith('SELECT id, quantity')){assert.match(sql,/AND org_id = \? AND is_active = 1 FOR UPDATE/);assert.deepEqual(args,['QA-1','TENANT_A']);return[deleted?[]:[{id:7,current_qty:'5.125'}]];}return[{insertId:9,affectedRows:1}];
}};
require.cache[require.resolve('../../api/database/connection')]={exports:{pool:{getConnection:async()=>{connections++;if(failConnection)throw Error('TEST_POOL_DOWN');return connection;}}}};
require.cache[require.resolve('../../api/middleware/auth')]={exports:(req,_res,next)=>{req.user={id:1,org_id:'TENANT_A',role:req.headers['x-role']||'admin',email:'qa@example.invalid'};next();}};
const app=express();app.use(express.json());app.use('/movements',require('../../api/routes/movements'));const server=app.listen(0,'127.0.0.1');after(()=>new Promise(resolve=>server.close(resolve)));
async function send(route,body,role='admin'){if(!server.listening)await new Promise(r=>server.once('listening',r));return fetch('http://127.0.0.1:'+server.address().port+'/movements/'+route,{method:'POST',headers:{'content-type':'application/json','x-role':role},body:JSON.stringify(body)});}
test('material numeric values reject coercion, negatives, overflow and precision loss',()=>{
 for(const field of ['quantity','min_qty','max_qty','unit_price'])for(const value of [-1,'1',null,[],Infinity,1e10])assert.throws(()=>validateMaterialValues({[field]:value}),e=>e.status===400);
 for(const body of [{quantity:.0001},{min_qty:.5},{max_qty:1.25},{unit_price:1.005},{description:[]},{description:'  '}])assert.throws(()=>validateMaterialValues(body),e=>e.status===400);
 assert.doesNotThrow(()=>validateMaterialValues({quantity:1.125,min_qty:0,max_qty:10,unit_price:12.34}));
});
test('movement records retain decimal quantity and the explicitly supplied purchase price',async()=>{
 calls=[];commits=rollbacks=releases=0;const result=await send('entry',{code:'QA-1',quantity:.125,unit_price:12.34});assert.equal(result.status,201);assert.equal((await result.json()).new_stock,5.25);const recorded=calls.find(c=>c.sql.startsWith('INSERT INTO movements'));assert.match(recorded.sql,/created_by/);assert.equal(recorded.args.at(-1),1);const valuation=calls.find(c=>c.sql.startsWith('INSERT INTO movement_valuation'));assert.deepEqual(valuation.args,[9,12.34,7,'TENANT_A']);assert.match(valuation.sql,/COALESCE\(\?,unit_price\)/);assert.equal(commits,1);assert.equal(releases,1);assert.equal(rollbacks,0);
 calls=[];assert.equal((await send('entry',{code:'QA-1',quantity:.125})).status,201);assert.equal(calls.find(c=>c.sql.startsWith('INSERT INTO movement_valuation')).args[1],null);
});
test('inactive materials and viewers cannot create stock movements',async()=>{
 deleted=true;try{for(const route of ['entry','exit'])assert.equal((await send(route,{code:'QA-1',quantity:.125})).status,404);}finally{deleted=false;}
 const before=connections;assert.equal((await send('exit',{code:'QA-1',quantity:1},'viewer')).status,403);assert.equal(connections,before);
});
test('invalid movement values do not acquire a connection; pool failure returns a bounded error',async()=>{
 const before=connections;for(const body of [{quantity:.0001},{quantity:-1},{quantity:1,unit_price:-1},{quantity:1,unit_price:'2'},{quantity:1,unit_price:1.005}])assert.equal((await send('entry',{code:'QA-1',...body})).status,400);assert.equal(connections,before);
 failConnection=true;const original=console.error;console.error=()=>{};try{for(const route of ['entry','exit']){const result=await send(route,{code:'QA-1',quantity:1});assert.equal(result.status,500);assert.equal((await result.json()).error,route==='entry'?'Erro ao registrar entrada':'Erro ao registrar saída');}}finally{failConnection=false;console.error=original;}
});
