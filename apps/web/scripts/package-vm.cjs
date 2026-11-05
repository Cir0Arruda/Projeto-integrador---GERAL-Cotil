'use strict';
// Build an explicit source-only release. No credential/profile/dependency directory is traversed.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
async function main(){
  const files=['index.html','api/server.js','api/production-start.cjs','api/package.json','api/package-lock.json'];
  async function walk(relative){for(const entry of await fs.readdir(path.join(root,relative),{withFileTypes:true})){
    const file=relative+'/'+entry.name;
    if(entry.isSymbolicLink()||/[\r\n\0]/.test(file)||entry.name.startsWith('.'))throw Error('RELEASE_UNEXPECTED_FILE');
    if(entry.isDirectory())await walk(file);
    else if(entry.isFile()){
      if(!/\.(?:html|css|js|cjs|json|sql|wasm|png|jpg|jpeg|svg|webp|ico|woff|woff2)$/i.test(entry.name)&&!/^app\/vendor\/occt-import-js\/license[.a-z-]*\.txt$/.test(file))throw Error('RELEASE_FILE_TYPE_REJECTED');
      files.push(file);
    }
  }}
  for(const directory of ['app','api/routes','api/services','api/middleware','api/security','api/database'])await walk(directory);
  const directory=path.join(root,'dist','vm');await fs.mkdir(directory,{recursive:true});
  const archive=path.join(directory,'astha-vm-'+Date.now()+'.tar.gz'),list=archive+'.files';
  await fs.writeFile(list,files.sort().join('\0')+'\0',{flag:'wx'});
  const result=spawnSync('tar',['--null','-czf',archive,'-T',list],{cwd:root,windowsHide:true,shell:false,stdio:'ignore'});
  if(result.status!==0)throw Error('RELEASE_ARCHIVE_FAILED');
  const sha256=crypto.createHash('sha256').update(await fs.readFile(archive)).digest('hex');
  await fs.writeFile(archive+'.sha256',sha256+'  '+path.basename(archive)+'\n',{flag:'wx'});
  console.log(JSON.stringify({archive,sha256,files:files.length,secretsIncluded:false}));
}
if(require.main===module)main().catch(e=>{console.error('RELEASE_FAILED',e.code||e.message);process.exitCode=1;});
module.exports={main};
