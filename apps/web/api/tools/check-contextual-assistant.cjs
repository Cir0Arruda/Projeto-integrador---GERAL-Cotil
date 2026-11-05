'use strict';
// All database fixtures are rolled back. --gemini sends only synthetic questions and anonymous results.
const assert = require('node:assert/strict'), crypto = require('node:crypto');
(async () => {
  const profile = await require('../security/local-profile').load();
  if (profile.DB_NAME !== 'astha_raven_lab') throw Error('Lab required');
  Object.assign(process.env, profile);
  const { pool } = require('../database/connection'), service = require('../services/contextual-assistant');
  const db = await pool.getConnection(), org = 'qa_context_' + crypto.randomBytes(6).toString('hex');
  const user = { id: 1, org_id: org, role: 'admin' }; let conversationId;
  try {
    await db.beginTransaction();
    await db.execute('INSERT INTO organizations (id,name) VALUES (?,?)', [org, 'Disposable contextual QA']);
    const ids = [];
    for (const [code, status] of [['QA-A', 'active'], ['QA-B', 'maintenance']]) {
      const [created] = await db.execute('INSERT INTO assets (org_id,asset_code,name,status,criticality) VALUES (?,?,?,?,?)', [org, code, 'PRIVATE NAME NOT SENT TO PROVIDER', status, 'high']); ids.push(created.insertId);
    }
    await db.execute("INSERT INTO maintenance_work_orders (org_id,asset_id,title,work_order_number,status) VALUES (?,?,?,?,'open')", [org, ids[1], 'PRIVATE ORDER TITLE', 'QA-OS']);
    const state = { refs: new Map(), next: 1 };
    const assets = await service.readTool(db, user, { module: 'assets' }, state, {});
    assert.equal(assets.summary.total, 2); assert.equal(assets.sources.length, 2);
    assert.equal((await service.readTool(db, user, { module: 'assets', status: 'maintenance' }, state, {})).sources.length, 1);
    const ref = assets.sources.find(s => s.id === ids[1]).ref;
    assert.equal((await service.readTool(db, user, { module: 'work_orders', ref }, state, {})).summary.total, 1);
    assert.equal((await service.readTool(db, { ...user, org_id: org + '_foreign' }, { module: 'assets' }, { refs: new Map(), next: 1 }, {})).summary.total, 0);
    assert.equal((await service.readTool(db, user, { module: 'assets', search: "' OR 1=1 --" }, state, {})).summary.total, 0);
    assert.equal((await service.readTool(db, user, { module: 'maps' }, state, {})).summary.total, 0);
    const insert = async (sql, params) => (await db.execute(sql, params))[0].insertId;
    const warehouses = [], layouts = [];
    for (const label of ['visible','archived','other-visible']) {
      const layout = await insert("INSERT INTO warehouse_layout (org_id,name,room_w,room_h,door_x,door_y,door_w,blueprint_data) VALUES (?,?,720,480,620,480,100,'{}')", [org,label]); layouts.push(layout);
      const warehouse = await insert('INSERT INTO warehouses (org_id,name) VALUES (?,?)',[org,label]); warehouses.push(warehouse);
      await db.execute('INSERT INTO warehouse_context (warehouse_id,org_id,layout_id) VALUES (?,?,?)',[warehouse,org,layout]);
    }
    await db.execute('INSERT INTO warehouse_map_meta (layout_id,org_id,archived_at) VALUES (?,?,NOW())',[layouts[1],org]);
    const materialIds = [];
    for (const [code,warehouse,active] of [['QA-VISIBLE',warehouses[0],1],['QA-DELETED',warehouses[0],0],['QA-ARCHIVED',warehouses[1],1],['QA-OTHER',warehouses[2],1],['QA-UNASSIGNED',null,1]]) materialIds.push(await insert('INSERT INTO materials (org_id,warehouse_id,code,description,quantity,min_qty,is_active) VALUES (?,?,?,?,1,5,?)',[org,warehouse,code+'-'+org.slice(-6),'Fixture',active]));
    const current=await service.readTool(db,user,{module:'stock',status:'low'},state,{warehouseId:warehouses[0]});
    assert.equal(current.summary.total,1);assert.match(current.sources[0].label,/^QA-VISIBLE-/);
    const all=await service.readTool(db,user,{module:'stock',status:'low'},state,{});assert.equal(all.summary.total,2);assert.ok(!all.sources.some(s=>/DELETED|ARCHIVED|UNASSIGNED/.test(s.label)));
    await assert.rejects(service.readTool(db,{...user,org_id:org+'_foreign'},{module:'stock'},state,{warehouseId:warehouses[0]}),{status:404});
    await db.execute('UPDATE warehouse_map_meta SET archived_at=NULL WHERE layout_id=? AND org_id=?',[layouts[1],org]);
    assert.equal((await service.readTool(db,user,{module:'stock',status:'low'},state,{})).summary.total,3);
    await db.execute('UPDATE materials SET is_active=0 WHERE id=? AND org_id=?',[materialIds[0],org]);
    assert.equal((await service.readTool(db,user,{module:'stock',ref:current.sources[0].ref},state,{warehouseId:warehouses[0]})).summary.total,0);
    console.log('Stock visibility: deleted materials, archived maps, unassigned rows, selected warehouse, cross-tenant IDs, restore and stale references passed.');
    console.log('Contextual MySQL: assets, maintenance status, asset work orders, tenant isolation, parameterized search and maps passed.');
    if (process.argv.includes('--gemini')) {
      assert.ok(process.env.GEMINI_API_KEY, 'Gemini key must be configured on server');
      const payloads = [];
      const fetcher = async (url, options) => {
        assert.ok(!options.body.includes('PRIVATE')); assert.ok(!options.body.includes(org));
        payloads.push(JSON.parse(options.body)); const response = await fetch(url, options);
        if (!response.ok) { const detail = await response.clone().json().catch(() => ({})); console.log('Gemini status:', response.status, 'detail:', service.privateText(String(detail.error?.message || 'unavailable').split(process.env.GEMINI_API_KEY).join('[redacted]'))); }
        else { const result = await response.clone().json(); console.log('Gemini calls:', result.candidates?.[0]?.content?.parts?.filter(p=>p.functionCall).map(p=>({tool:p.functionCall.name,module:p.functionCall.args?.module,refs:p.functionCall.args?.refs,ref:p.functionCall.args?.ref}))); }
        return response;
      };
      const options = { fetcher, onFallback: error => console.log('Fallback reason:', error.name, ['Invalid function calls','Mixed final response','Invalid final answer','Tool limit','No grounded response','Invalid provider response','Provider unavailable'].includes(error.message) ? error.message : '') };
      const first = await service.answer(db, user, { question: 'Quais são os ativos que eu tenho cadastrado?' }, options); conversationId = first.conversationId;
      assert.equal(first.mode, 'gemini', 'first question must use Gemini'); assert.equal(first.sources.length, 2); assert.equal(first.queries[0].module, 'assets');
      const followup = await service.answer(db, user, { question: 'E quais deles estão em manutenção?', conversationId }, options);
      assert.equal(followup.mode, 'gemini', 'maintenance follow-up must use Gemini'); assert.equal(followup.sources.length, 1); assert.equal(followup.sources[0].status, 'maintenance');
      const orders = await service.answer(db, user, { question: 'Esse que está em manutenção tem alguma ordem de serviço?', conversationId }, options);
      assert.equal(orders.mode, 'gemini', 'related orders must use Gemini'); assert.ok(orders.sources.some(s => s.kind === 'work_orders'));
      console.log('Live Gemini: screenshot question, contextual maintenance follow-up, related work orders and anonymous provider payloads passed. Requests:', payloads.length);
    }
  } finally {
    if (conversationId) service.clear(user, conversationId);
    await db.rollback(); db.release(); await pool.end();
  }
})().catch(error => { console.error('Contextual QA failed:', error.code || error.name, error.name === 'AssertionError' ? error.message : ''); process.exitCode = 1; });
