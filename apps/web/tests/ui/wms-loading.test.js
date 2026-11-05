const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const root = path.resolve(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'app/sistema.html'), 'utf8');

test('simple stock list renders dedicated and legacy images with accessible placeholders', () => {
  const dom = new JSDOM(html, { runScripts: 'outside-only', url: 'http://localhost/app/sistema.html' });
  const w = dom.window;
  try {
    w.Auth = { requireAuth: () => false, canEdit: () => false };
    w.eval(fs.readFileSync(path.join(root, 'app/js/security.js'), 'utf8') + '\n' + fs.readFileSync(path.join(root, 'app/js/sistema-core.js'), 'utf8') + `
      formatBRL=n=>String(n);getStatus=()=>({cls:'',text:''});
      materials=[{code:'A',description:'Motor',image_data:'data:image/png;base64,AAAA'},
        {code:'B',description:'Caixa',notes:JSON.stringify({image:'/images/box.png'})},
        {code:'C',description:'Sem foto'}].map(mapMaterialToFrontend);renderStock();`);
    const pictures = [...w.document.querySelectorAll('#stockTableBody img')];
    assert.equal(pictures.length, 2);
    assert.equal(pictures[0].getAttribute('src'), 'data:image/png;base64,AAAA');
    assert.equal(pictures[1].getAttribute('src'), '/images/box.png');
    assert.equal(pictures[0].alt, 'Motor');
    assert.equal(w.document.querySelectorAll('#stockTableBody .eo-thumb-placeholder').length, 1);
  } finally { w.close(); }
});

test('decimal stock is summed numerically and zero stock is classified correctly', () => {
  const dom = new JSDOM(html, { runScripts: 'outside-only' });
  const w = dom.window;
  try {
    w.Auth = { requireAuth: () => false };
    w.eval(fs.readFileSync(path.join(root, 'app/js/security.js'), 'utf8') + '\n' + fs.readFileSync(path.join(root, 'app/js/sistema-core.js'), 'utf8') + `
drawDonut=()=>{};formatBRL=n=>String(n);getStatus=()=>({cls:'',text:''});
      materials=[{quantity:'34.000',unit_price:'2',min_qty:'40'}, {quantity:'1.250',unit_price:'4',min_qty:'2'}, {quantity:'0.000',unit_price:'9',min_qty:'1'}].map(mapMaterialToFrontend);
      renderDashboard();`);
    assert.equal(w.document.getElementById('statTotalQty').textContent, '35,25');
    assert.equal(w.document.getElementById('statTotalValue').textContent, '73');
    assert.equal(w.document.getElementById('statZero').textContent, '1');
    assert.equal(w.document.getElementById('statCritical').textContent, '2');
  } finally { w.close(); }
});

test('map hub exposes the authenticated warehouse blueprint without copying or saving it', async () => {
  const dom = new JSDOM(html, { runScripts: 'outside-only' });
  const w = dom.window;
  try {
    const calls = [];
    w.API = { get: async endpoint => {
      calls.push(endpoint);assert.equal(endpoint,'/warehouse/map-hub');
      return {success:true,data:{maps:[{id:'cad-5',source:'cad',layout_id:5,warehouse_id:7,warehouse_ids:[7],type:'stock',name:'Planta existente',sectors:[],items:[]}]}};
    }};
    w.currentWarehouseId=7;w.eval(fs.readFileSync(path.join(root,'app/js/warehouse-workspace.js'),'utf8'));
    let loaded = 0;
    w.loadBlueprint = async () => { loaded++; };
    const script = [...w.document.scripts].find(script => script.textContent.includes('async function loadMaps('));
    w.eval(script.textContent);
    await new Promise(resolve => setImmediate(resolve));
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(w.document.getElementById('mhStatStockMaps').textContent, '1');
    assert.equal(w.document.querySelector('#mhStockList .maphub-map-name').textContent, 'Planta existente');
    assert.equal(loaded, 1);
    assert.deepEqual(calls.sort(), ['/warehouse/map-hub']);
    assert.equal(w._mapHub.currentMapId,'cad-5');
  } finally { w.close(); }
});
