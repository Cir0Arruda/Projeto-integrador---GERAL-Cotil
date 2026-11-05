'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
const { validPassword } = require('../../api/security/password-policy');
test('registration rejects weak and byte-truncated passwords before contacting API', async () => {
  let posts = 0;
  const fields = Object.fromEntries(['regName','regEmail','regPass','regPassConfirm','toast',
    'regDob','regGender','regCountry','regPhone','createAccountButton'].map(key => [key,
      { value: '', focus() {}, scrollIntoView() {}, textContent: '', hidden: false }]));
  fields.regName.value = 'Usuário Sintético'; fields.regEmail.value = 'test@example.invalid';
  const context = vm.createContext({ document: { addEventListener() {}, getElementById: key => fields[key] },
    API: { post: async () => { posts++; return { success: false, error: 'Resposta de teste' }; } }, TextEncoder });
  vm.runInContext(fs.readFileSync(require.resolve('../../app/js/register-wizard.js'), 'utf8'), context);
  for (const password of ['short', 'a'.repeat(15), 'password123456789', 'é'.repeat(40), 'Uma frase privada 2026!']) {
    const before = posts; fields.regPass.value = fields.regPassConfirm.value = password;
    await context.finishRegistration();
    assert.equal(posts - before, validPassword(password) ? 1 : 0);
  }
});
