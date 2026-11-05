/* Shared Web/Desktop → Flutter material QR contract. Contains identifiers only. */
(function(root){
  'use strict';
  const api={payload(code,org){
    if(typeof code!=='string'||!code||code.length>100||/[\x00-\x1f]/.test(code)||typeof org!=='string'||!org||org.length>100)throw Error('Material ou organização inválidos.');
    return JSON.stringify({kind:'astha-material',v:1,code,org});
  }};
  root.ASTHAMaterialQr=api;
  if(typeof module!=='undefined')module.exports=api;
})(typeof window==='undefined'?globalThis:window);
