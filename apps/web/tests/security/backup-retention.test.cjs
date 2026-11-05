'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {retentionCandidates} = require('../../scripts/maintenance/backup-vps-scheduled.cjs');
test('backup retention preserves 30 newest, recent and invalid/future snapshots', () => {
  const now = Date.UTC(2026, 10, 5), day = 86400000;
  const entries = Array.from({length: 40}, (_, i) => ({directory: 'snapshot-' + i, time: now - i * day}));
  const result = retentionCandidates([...entries, {time: NaN}, {time: now + day}], now);
  assert.deepEqual(result.map(item => item.directory), entries.slice(31).map(item => item.directory));
  assert.deepEqual(retentionCandidates(entries.slice(0, 20), now), []);
  assert.equal(entries.length, 40);
});
