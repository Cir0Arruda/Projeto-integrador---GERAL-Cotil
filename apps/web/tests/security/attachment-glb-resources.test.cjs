'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {validateAttachment}=require('../../api/security/attachments');
function glb(json) {
  const raw=Buffer.from(JSON.stringify(json));
  const padded=Buffer.alloc(Math.ceil(raw.length/4)*4,32);raw.copy(padded);
  const header=Buffer.alloc(20);header.write('glTF');header.writeUInt32LE(2,4);
  header.writeUInt32LE(20+padded.length,8);header.writeUInt32LE(padded.length,12);
  header.writeUInt32LE(0x4e4f534a,16);return Buffer.concat([header,padded]);
}
const attachment=bytes=>({filename:'fixture.glb',file_data:bytes.toString('base64')});
test('GLB preserves real authored geometry and embedded data resources',()=>{
  const {bytes}=require('../fixtures/industrial-glb.cjs')();
  assert.equal(validateAttachment(attachment(Buffer.from(bytes))).mime_type,'model/gltf-binary');
  assert.ok(validateAttachment(attachment(glb({asset:{version:'2.0'},buffers:[{uri:'data:application/octet-stream;base64,AAAA'}]}))));
});
test('GLB rejects external image/buffer fetches as text glTF already does',()=>{
  for(const field of ['buffers','images'])for(const uri of ['https://example.invalid/track','http://127.0.0.1/private','//example.invalid/a','file:///C:/private','relative.bin']){
    const document={asset:{version:'2.0'},[field]:[{uri}]};
    assert.throws(()=>validateAttachment(attachment(glb(document))),field+' '+uri);
    assert.throws(()=>validateAttachment({filename:'fixture.gltf',file_data:Buffer.from(JSON.stringify(document)).toString('base64')}));
  }
});
test('GLB structural corruption, missing JSON and malformed resource shapes fail before storage',()=>{
  const valid=glb({asset:{version:'2.0'}});
  const truncated=Buffer.from(valid);truncated.writeUInt32LE(99999,12);
  const wrongType=Buffer.from(valid);wrongType.writeUInt32LE(0x004e4942,16);
  for(const bytes of [valid.subarray(0,12),truncated,wrongType,glb({asset:{version:'2.0'},images:{uri:'data:image/png;base64,AAAA'}})])
    assert.throws(()=>validateAttachment(attachment(bytes)));
});

test('large valid attachments and embedded buffers do not exhaust the regexp stack',()=>{
  const embedded=Buffer.alloc(2*1024*1024,17).toString('base64');
  const bytes=glb({asset:{version:'2.0'},buffers:[{uri:'data:application/octet-stream;base64,'+embedded}]});
  assert.equal(validateAttachment(attachment(bytes)).mime_type,'model/gltf-binary');
  const stl=Buffer.alloc(84+50*60000);stl.writeUInt32LE(60000,80);
  assert.equal(validateAttachment({filename:'large.stl',file_data:stl.toString('base64')}).mime_type,'application/octet-stream');
  for(const raw of ['AAAA=','AA=A','AAA','AA!A','A===','AAAA\n'])
    assert.throws(()=>validateAttachment({filename:'invalid.stl',file_data:raw}),/Base64 inválido/);
  const bad=glb({asset:{version:'2.0'},images:[{uri:'data:image/png;base64,AAAA=AAA'}]});
  assert.throws(()=>validateAttachment(attachment(bad)),/Tipo ou conteúdo/);
});
