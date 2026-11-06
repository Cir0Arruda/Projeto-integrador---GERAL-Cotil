'use strict';
const {test} = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');
const {JSDOM} = require('../node_modules/jsdom');
const {create} = require('../../app/js/wms-live-stock');
const settle = async () => { await new Promise(resolve => setImmediate(resolve)); await new Promise(resolve => setImmediate(resolve)); };
function harness() {
  let clock = 0, visible = true, blocked = false, reads = 0, changed = 0;
  let scope = {token: 'synthetic', orgId: 'org-a', userId: 1, warehouseId: 7, loadVersion: 1, revision: 0};
  const tasks = new Map(), published = [], states = [], view = new EventTarget(), doc = new EventTarget();
  let next = 0, reader = async () => ({success: true, data: [{quantity: reads}]});
  const controller = create({window: view, document: doc, now: () => clock,
    setTimer: (callback, delay) => {tasks.set(++next, {callback, at: clock + delay}); return next;}, clearTimer: id => tasks.delete(id),
    context: () => ({...scope}), visible: () => visible, blocked: () => blocked,
    read: async context => {reads++; return reader(context);}, publish: rows => published.push(rows),
    status: state => states.push(state), identityChanged: () => changed++});
  async function advance(ms) {clock += ms; for (const [id, task] of [...tasks]) if (task.at <= clock) {tasks.delete(id); task.callback();} await settle();}
  return {controller, tasks, published, states, view, doc, advance,
    get reads() {return reads;}, get changed() {return changed;},
    set visible(value) {visible = value;}, set blocked(value) {blocked = value;}, set scope(value) {scope = {...scope, ...value};}, set reader(value) {reader = value;}};
}
test('stock polls at 5 seconds while visible and refreshes on focus/return only', async () => {
  const h = harness(); h.controller.start(); await settle(); assert.equal(h.reads, 1);
  await h.advance(4999); assert.equal(h.reads, 1); await h.advance(1); assert.equal(h.reads, 2);
  h.visible = false; h.doc.dispatchEvent(new Event('visibilitychange')); await settle(); assert.equal(h.tasks.size, 0);
  await h.advance(60000); assert.equal(h.reads, 2);
  h.visible = true; h.doc.dispatchEvent(new Event('visibilitychange')); await settle(); assert.equal(h.reads, 3);
  h.view.dispatchEvent(new Event('focus')); await settle(); assert.equal(h.reads, 4);
  h.controller.dispose(); assert.equal(h.tasks.size, 0);
});
test('editing suspends requests and discards data if editing starts during a fetch', async () => {
  const h = harness(); let finish; h.blocked = true; h.controller.start(); await settle(); assert.equal(h.reads, 0);
  h.blocked = false; h.reader = () => new Promise(resolve => {finish = resolve;});
  const pending = h.controller.refresh(); await settle(); h.blocked = true;
  finish({success: true, data: [{quantity: 9}]}); await pending; assert.equal(h.published.length, 0);
  h.controller.dispose();
});
test('focus bursts cannot overlap requests and only one follow-up is queued', async () => {
  const h = harness(); let finish, active = 0, max = 0;
  h.reader = () => new Promise(resolve => {active++; max = Math.max(max, active); finish = answer => {active--; resolve(answer);};});
  h.controller.start(); await settle(); for (let n = 0; n < 8; n++) h.view.dispatchEvent(new Event('focus'));
  assert.equal(h.reads, 1); finish({success: true, data: []}); await settle(); assert.equal(h.reads, 2); assert.equal(max, 1);
  h.controller.dispose(); finish({success: true, data: []}); await settle(); assert.equal(h.tasks.size, 0);
});
test('warehouse, bootstrap and write revision changes discard late snapshots', async () => {
  for (const update of [{warehouseId: 8}, {loadVersion: 2}, {revision: 1}]) {
    const h = harness(); let finish; h.reader = () => new Promise(resolve => {finish = resolve;});
    h.controller.start(); await settle(); h.scope = update; finish({success: true, data: [{quantity: 9}]}); await settle();
    assert.equal(h.published.length, 0); h.controller.dispose();
  }
});
test('identity change stops polling and clears the old identity through its callback', async () => {
  const h = harness(); let finish; h.reader = () => new Promise(resolve => {finish = resolve;});
  h.controller.start(); await settle(); h.scope = {token: 'other', orgId: 'org-b'};
  h.view.dispatchEvent(new Event('storage')); await settle(); finish({success: true, data: [{quantity: 9}]}); await settle();
  assert.equal(h.published.length, 0); assert.equal(h.changed, 1); assert.equal(h.tasks.size, 0);
});
test('failed refresh preserves data, backs off and honors server Retry-After', async () => {
  const h = harness(); h.controller.start(); await settle(); assert.equal(h.published.length, 1);
  h.reader = async () => ({success: false, status: 429, retryAfter: 30}); await h.controller.refresh();
  assert.equal(h.published.length, 1); assert.equal(h.states.at(-1), 'unavailable');
  await h.advance(5000); assert.equal(h.reads, 2); h.view.dispatchEvent(new Event('focus')); await settle(); assert.equal(h.reads, 2);
  await h.advance(25000); assert.equal(h.reads, 3); h.controller.dispose();
});
test('BFCache pauses polling and resumes without duplicating subscriptions', async () => {
  const h = harness(); h.controller.start(); h.controller.start(); await settle();
  const event = new Event('pagehide'); event.persisted = true; h.view.dispatchEvent(event); await h.advance(10000); assert.equal(h.reads, 1);
  h.view.dispatchEvent(new Event('pageshow')); await settle(); assert.equal(h.reads, 2); h.controller.dispose();
});
test('stock publication preserves the search input and renders the newly authorized values', () => {
  const root = path.resolve(__dirname, '../..');
  const dom = new JSDOM(fs.readFileSync(path.join(root, 'app/sistema.html'), 'utf8'), {runScripts: 'outside-only'});
  const w = dom.window;
  try {
    w.Auth = {requireAuth: () => false, canEdit: () => false};
    w.eval(fs.readFileSync(path.join(root, 'app/js/security.js'), 'utf8') + '\n' + fs.readFileSync(path.join(root, 'app/js/sistema-core.js'), 'utf8') + `
      document.getElementById('stockFilter').value='FILTER-ME';
      materials=[{code:'FILTER-ME',description:'Selected',quantity:3},{code:'OTHER',description:'Other',quantity:9}].map(mapMaterialToFrontend);
      renderStock();window.updateStockQaQuantity=()=>{materials[0].qty=4;renderStock();};`);
    assert.equal(w.document.querySelectorAll('#stockTableBody tr').length, 1);
    assert.equal(w.document.getElementById('stockFilter').value, 'FILTER-ME');
    assert.equal(w.document.querySelector('#stockTableBody tr').children[6].textContent, '3');
    w.document.querySelector('#stockTableBody [data-action="info"]').focus();
    w.updateStockQaQuantity();
    assert.equal(w.document.activeElement.dataset.action, 'info');
    assert.equal(w.document.activeElement.closest('tr').querySelector('.material-code').textContent, 'FILTER-ME');
    assert.equal(w.document.querySelector('#stockTableBody tr').children[6].textContent, '4');
  } finally {w.close();}
});
