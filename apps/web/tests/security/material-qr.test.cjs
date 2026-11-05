const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const qr=require('../../app/js/material-qr');
test('material QR has the same scoped contract consumed by Flutter',()=>{
 assert.deepEqual(JSON.parse(qr.payload('A-1','org-a')),{kind:'astha-material',v:1,code:'A-1',org:'org-a'});
 for(const code of ['',null,'a'.repeat(101),'\0'])assert.throws(()=>qr.payload(code,'org-a'));
 const generator=require('../../app/vendor/qrcode-generator/qrcode');const result=generator(0,'M');result.addData(qr.payload('A-1','org-a'));result.make();assert.ok(result.getModuleCount()>20);assert.match(result.createDataURL(),/^data:image\/gif;base64,/);
});
test('Web QR generation does not disclose inventory identifiers to an external QR service',()=>{
 const source=fs.readFileSync(require.resolve('../../app/js/sistema-core'),'utf8');assert.ok(!source.includes('api.qrserver.com'));assert.ok(source.includes('ASTHAMaterialQr.payload'));
 const html=fs.readFileSync('app/sistema.html','utf8');assert.ok(html.indexOf('vendor/qrcode-generator/qrcode.js')<html.indexOf('js/sistema-core.js'));
});
