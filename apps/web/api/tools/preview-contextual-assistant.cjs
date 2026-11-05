'use strict';
(async () => {
  const fixture = await require('./personal-qa-fixture.cjs')(); let user;
  async function close() {
    if (user) {
      await fixture.pool.execute('DELETE FROM assets WHERE BINARY org_id=BINARY ?', [user.org_id]);
      await fixture.pool.execute('UPDATE materials SET is_active=0 WHERE BINARY org_id=BINARY ?', [user.org_id]);
      await fixture.pool.execute('INSERT INTO warehouse_map_meta (layout_id,org_id,archived_at) SELECT id,org_id,NOW() FROM warehouse_layout WHERE BINARY org_id=BINARY ? ON DUPLICATE KEY UPDATE archived_at=NOW()', [user.org_id]);
    }
    await fixture.close();
  }
  try {
    user = await fixture.identity('assistant', 'corporate');
    const suffix=require('node:crypto').randomBytes(4).toString('hex');
    const insert = async (sql, params) => (await fixture.pool.execute(sql, params))[0].insertId;
    for (const archived of [false,true]) {
      const layout=await insert("INSERT INTO warehouse_layout (org_id,name,room_w,room_h,door_x,door_y,door_w,blueprint_data) VALUES (?,?,720,480,620,480,100,'{}')",[user.org_id,archived?'QA mapa arquivado':'QA mapa ativo']);
      const warehouse=await insert('INSERT INTO warehouses (org_id,name) VALUES (?,?)',[user.org_id,archived?'QA estoque arquivado':'QA estoque ativo']);
      await fixture.pool.execute('INSERT INTO warehouse_context (warehouse_id,org_id,layout_id) VALUES (?,?,?)',[warehouse,user.org_id,layout]);
      if(archived)await fixture.pool.execute('INSERT INTO warehouse_map_meta (layout_id,org_id,archived_at) VALUES (?,?,NOW())',[layout,user.org_id]);
      const material=await insert("INSERT INTO materials (org_id,warehouse_id,code,description,brand,sector,location,quantity,min_qty,unit_price,currency,is_active) VALUES (?,?,?,?,?,?,?,8,9,6875,'BRL',1)",[user.org_id,warehouse,(archived?'QA-ARCHIVED-':'QA-MOTOR-')+suffix,archived?'Material de mapa arquivado':'Motor elétrico de teste','Marca QA','Elétrica','SH-1-N3-P3']);
      if(!archived){
        const zero=await insert("INSERT INTO materials (org_id,warehouse_id,code,description,quantity,min_qty,unit_price,currency,is_active) VALUES (?,?,?,?,10,2,0,'BRL',1)",[user.org_id,warehouse,'QA-ZERO-'+suffix,'Item de teste sem custo']);
        for(const [id,price,date] of [[material,6875,'2026-10-06 10:00:00'],[zero,0,'2026-10-14 10:00:00']]){const movement=await insert("INSERT INTO movements (material_id,type,quantity,created_at) VALUES (?,'entrada',2,?)",[id,date]);await insert('INSERT INTO movement_valuation (movement_id,warehouse_id,unit_price,org_id) VALUES (?,?,?,?)',[movement,warehouse,price,user.org_id]);}
        await insert('INSERT INTO materials (org_id,warehouse_id,code,description,quantity,min_qty,is_active) VALUES (?,?,?,?,1,5,0)',[user.org_id,warehouse,'QA-DELETED-'+suffix,'Material excluído de teste']);
      }
    }
    for (const [code, name, status] of [['EQ-QA-01', 'Bomba de abastecimento', 'active'], ['EQ-QA-02', 'Compressor de ar', 'maintenance']]) {
      await fixture.pool.execute('INSERT INTO assets (org_id,asset_code,name,status,criticality) VALUES (?,?,?,?,?)', [user.org_id, code, name, status, 'high']);
    }
    const { origin, app } = await fixture.start(), bootstrap = '/__assistant_qa/' + require('node:crypto').randomBytes(16).toString('hex');
    app.get(bootstrap, (req, res) => {
      res.set('Cache-Control', 'no-store'); res.send('<!doctype html><title>QA Assistente ASTHA</title><script>localStorage.setItem("astha_token",' + JSON.stringify(user.token) + ');location.replace("/app/home.html");</script>');
    });
    app.post(bootstrap + '/finish', (req, res) => { res.json({ closing: true }); close().then(() => process.exit(0)); });
    console.log('QA_BROWSER_URL ' + origin + bootstrap);
    process.on('SIGINT', () => close().then(() => process.exit(0)));
  } catch (error) { await close(); throw error; }
})().catch(error => { console.error('ASSISTANT_PREVIEW_FAILED', error.code || error.name); process.exitCode = 1; });
