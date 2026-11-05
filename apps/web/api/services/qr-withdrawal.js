'use strict';
const bcrypt=require('bcryptjs'),sync=require('./mobile-sync');
const fail=(message,status=400)=>Object.assign(Error(message),{status});
async function withdraw(pool,user,body){
 if(!['superadmin','admin','manager','operator'].includes(user.role))throw fail('Sem permissão para retirar materiais.',403);
 const password=body?.current_password;
 if(typeof password!=='string'||!password||Buffer.byteLength(password)>72)throw fail('Informe a senha atual da sua conta.');
 const op={id:body.operation_id,method:'POST',path:'/api/movements/exit',body:{code:body.code,quantity:body.quantity,reason:body.reason??'Retirada por QR Code',...(body.notes!=null?{notes:body.notes}:{})}};
 sync.operation(op);
 const [rows]=await pool.execute('SELECT password_hash,provider FROM users WHERE id=? AND org_id=? AND is_active=1',[user.id,user.org_id]);
 if(!rows.length)throw fail('Sessão inválida.',401);
 if(rows[0].provider!=='local')throw fail('Esta retirada exige uma conta com senha local do ASTHA.',403);
 if(!rows[0].password_hash||!await bcrypt.compare(password,rows[0].password_hash))throw fail('Senha atual incorreta.',403);
 // Only public movement fields enter the durable idempotency ledger. No password
 // or client-provided biometric flag is stored or treated as server proof.
 return sync.apply(pool,user,op);
}
module.exports={withdraw};
