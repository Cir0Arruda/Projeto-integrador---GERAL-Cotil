'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

test('live verifier removes its own organization when user creation fails, without network or a real DB', async () => {
  let organization = null, ended = false, commits = 0;
  const db = {
    async execute(sql, values) {
      if (sql.startsWith('INSERT INTO organizations')) {
        organization = { id: values[0], name: values[1] };
        return [{ affectedRows: 1 }];
      }
      if (sql.startsWith('INSERT INTO users')) {
        throw Object.assign(new Error('Synthetic insert failure'), { code: 'QA_USER_INSERT_FAILED' });
      }
      if (sql.startsWith('DELETE FROM organizations')) {
        assert.equal(values[0], organization.id);
        assert.equal(values[1], organization.name);
        organization = null;
        return [{ affectedRows: 1 }];
      }
      if (sql.startsWith('DELETE ')) {
        assert.equal(values[0], organization.id);
        return [{ affectedRows: 0 }];
      }
      assert.equal(sql, 'SELECT COUNT(*) AS n FROM organizations WHERE id=?');
      return [[{ n: organization ? 1 : 0 }]];
    },
    async beginTransaction() {},
    async commit() { commits++; },
    async rollback() { assert.fail('Cleanup must commit'); },
    async end() { ended = true; },
  };
  const modules = {
    dotenv: { parse: () => ({ GEMINI_API_KEY: 'synthetic-unused-provider-key' }) },
    'mysql2/promise': { createConnection: async () => db },
    bcryptjs: { hash: async () => 'synthetic-hash' },
  };
  const context = vm.createContext({
    require(name) {
      if (name === 'node:fs/promises') return { readFile: async () => Buffer.from('synthetic-config') };
      if (name === 'node:module') return { createRequire: () => name => {
        assert.ok(Object.hasOwn(modules, name), 'Unexpected module');
        return modules[name];
      } };
      assert.ok(['node:crypto', 'node:assert/strict'].includes(name));
      return require(name);
    },
    module: { exports: {} },
    process: { getuid: () => 0 },
    console: { log() {}, error() {} },
    fetch() { assert.fail('User creation failed; no request may be sent'); },
  });
  const source = fs.readFileSync(path.resolve(__dirname, '../../deploy/vm/verify-gemini-live.cjs'), 'utf8');
  vm.runInContext(source, context, { timeout: 1000 });
  await assert.rejects(context.main(), { code: 'QA_USER_INSERT_FAILED' });
  assert.equal(organization, null);
  assert.equal(commits, 1);
  assert.equal(ended, true);
});
