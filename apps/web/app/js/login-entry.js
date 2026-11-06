(() => {
  const form = document.getElementById('loginForm');
  const password = document.getElementById('password');
  const toggle = document.getElementById('togglePassword');
  const error = document.getElementById('login-error-msg');
  const microsoftButton=document.getElementById('microsoftSignIn');
  async function acceptSession(result){
    if(!result.success||!result.token||!result.user)throw Error(result.error||'Não foi possível entrar.');
    localStorage.setItem('astha_token',result.token);localStorage.setItem('astha_user',JSON.stringify(result.user));
    const setupDone=typeof result.setup_done==='boolean'?result.setup_done:result.user.setup_done===true;
    const saved=sessionStorage.getItem('ASTHA_redirect');sessionStorage.removeItem('ASTHA_redirect');let destination=setupDone?'./home.html':'./onboarding.html';
    if(setupDone&&saved)try{const url=new URL(saved,location.href);if(url.origin===location.origin&&url.pathname.startsWith('/app/')&&!['/app/login.html','/app/register.html'].includes(url.pathname))destination=url.pathname+url.search;}catch(_){}
    location.assign(destination);
  }
  async function microsoft(){
    const params=new URLSearchParams(location.hash.slice(1)),credential=params.get('id_token');
    if(credential||params.has('error')){
      const nonce=sessionStorage.getItem('astha_ms_nonce'),state=sessionStorage.getItem('astha_ms_state');sessionStorage.removeItem('astha_ms_nonce');sessionStorage.removeItem('astha_ms_state');history.replaceState(null,'',location.pathname+location.search);
      try{if(!credential||!nonce||!state||params.get('state')!==state)throw Error('Login Microsoft não confirmado. Tente novamente.');await acceptSession(await API.post('/auth/oauth/microsoft',{id_token:credential,nonce}));}catch(failure){error.textContent=failure.message;error.hidden=false;}
    }
    const config=await API.get('/auth/oauth/microsoft/config');if(!config.success||!config.enabled)return;microsoftButton.hidden=false;
    microsoftButton.addEventListener('click',async()=>{microsoftButton.disabled=true;try{
      const provider=await API.get('/auth/oauth/microsoft/config');if(!provider.success||!provider.enabled)throw Error('Login Microsoft indisponível.');
      const state=crypto.randomUUID();sessionStorage.setItem('astha_ms_nonce',provider.nonce);sessionStorage.setItem('astha_ms_state',state);
      const query=new URLSearchParams({client_id:provider.clientId,redirect_uri:location.origin+'/app/login.html',response_type:'id_token',scope:'openid email profile',response_mode:'fragment',nonce:provider.nonce,state,prompt:'login'});
      location.assign('https://login.microsoftonline.com/'+provider.tenantId+'/oauth2/v2.0/authorize?'+query);
    }catch(failure){error.textContent=failure.message;error.hidden=false;microsoftButton.disabled=false;}});
  }
  if(microsoftButton)microsoft().catch(()=>{});
  toggle.addEventListener('click', () => {
    const show = password.type === 'password';
    password.type = show ? 'text' : 'password';
    toggle.textContent = show ? 'Ocultar' : 'Mostrar';
    toggle.setAttribute('aria-label', show ? 'Ocultar senha' : 'Mostrar senha');
    toggle.setAttribute('aria-pressed', String(show));
  });
  form.addEventListener('submit', async event => {
    event.preventDefault();
    const button = form.querySelector('[type=submit]');
    if (button.disabled) return;
    button.disabled = true;
    button.textContent = 'Entrando…';
    error.hidden = true;
    try {
      const result = await API.post('/auth/login', { email: form.elements.email.value.trim(), password: password.value });
      await acceptSession(result);
    } catch (failure) {
      error.textContent = failure.message || 'Não foi possível conectar. Tente novamente.';
      error.hidden = false;
    } finally { button.disabled = false; button.textContent = 'Entrar'; }
  });
})();
