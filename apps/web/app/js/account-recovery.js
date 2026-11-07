(() => {
 const form=document.getElementById('recoverAccountForm'),notice=document.getElementById('recoveryNotice');let busy=false,recovered=false;
 const emailSection=document.getElementById('recoveryEmailSection'),emailForm=document.getElementById('requestRecoveryEmailForm'),emailNotice=document.getElementById('recoveryEmailNotice');let emailBusy=false;
 if(emailSection){fetch('/api/account/recovery-options',{cache:'no-store'}).then(response=>response.ok?response.json():{}).then(options=>{
  if(recovered)return;emailSection.hidden=options.emailRecoveryAvailable!==true;document.getElementById('recoveryEmailUnavailable').hidden=!emailSection.hidden;
 }).catch(()=>{if(!recovered)document.getElementById('recoveryEmailUnavailable').hidden=false;});}
 emailForm?.addEventListener('submit',async event=>{
  event.preventDefault();if(emailBusy)return;emailBusy=true;const button=emailForm.querySelector('button'),original=button.textContent;button.disabled=true;button.textContent='Solicitando código…';emailForm.setAttribute('aria-busy','true');emailNotice.hidden=false;emailNotice.textContent='Aguarde…';
  try{
   const address=emailForm.elements.email.value.trim();
   const response=await fetch('/api/account/recover/email',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:address})});const result=await response.json();
   if(!response.ok)throw Error(result.error||'Não foi possível solicitar o código.');
   emailNotice.textContent=result.message;form.elements.email.value=address;form.elements.code.focus();
  }catch(error){emailNotice.textContent=error.message||'Não foi possível solicitar o código. Tente novamente.';}
  finally{emailBusy=false;button.disabled=false;button.textContent=original;emailForm.removeAttribute('aria-busy');}
 });
 form.addEventListener('submit',async event=>{event.preventDefault();if(busy)return;const data=new FormData(form);notice.hidden=false;if(data.get('new_password')!==data.get('confirm_password')){notice.textContent='A confirmação da senha não corresponde.';return;}busy=true;const button=form.querySelector('button');button.disabled=true;
  try{const response=await fetch('/api/account/recover',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:data.get('email'),code:data.get('code').trim(),new_password:data.get('new_password')})});const result=await response.json();if(!response.ok)throw Error(result.error||'Não foi possível recuperar o acesso.');form.reset();recovered=true;notice.textContent=result.message;form.hidden=true;if(emailSection)emailSection.hidden=true;const unavailable=document.getElementById('recoveryEmailUnavailable');if(unavailable)unavailable.hidden=true;const link=document.createElement('a');link.href='./login.html';link.textContent='Entrar com a nova senha';link.className='account-link';notice.hidden=false;form.before(notice);notice.after(link);}catch(error){notice.textContent=error.message||'Não foi possível recuperar o acesso.';form.elements.code.value='';form.elements.new_password.value='';form.elements.confirm_password.value='';}finally{busy=false;button.disabled=false;}
 });
})();
