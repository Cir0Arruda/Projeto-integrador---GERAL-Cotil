'use strict';
// Reproduce the existing CAD binary from its pinned npm package. No network,
// environment, database or application data is accessed by this script itself.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const source=path.join(root,'node_modules','occt-import-js');
const manifest=JSON.parse(fs.readFileSync(path.join(source,'package.json'),'utf8'));
if(manifest.version!=='0.0.23')throw Error('CAD_PACKAGE_VERSION_MISMATCH');
const bytes=fs.readFileSync(path.join(source,'dist','occt-import-js.wasm'));
if(crypto.createHash('sha256').update(bytes).digest('hex')!=='33391fc9d94ea5c869a6718488bf0a9a464222bac9bdc764dfe1690cef281952')throw Error('CAD_BINARY_INTEGRITY_MISMATCH');
const directory=path.join(root,'app','vendor','occt-import-js');
fs.mkdirSync(directory,{recursive:true});
const actual=fs.realpathSync(directory);
if(!actual.startsWith(fs.realpathSync(root)+path.sep))throw Error('CAD_OUTPUT_PATH_REJECTED');
const temp=path.join(actual,'occt-import-js.wasm.'+process.pid+'.tmp');
try{fs.writeFileSync(temp,bytes,{flag:'wx'});fs.renameSync(temp,path.join(actual,'occt-import-js.wasm'));}
finally{if(fs.existsSync(temp))fs.unlinkSync(temp);}
console.log('CAD binary prepared: occt-import-js 0.0.23, SHA-256 verified.');
