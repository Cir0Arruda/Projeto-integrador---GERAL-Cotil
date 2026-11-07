'use strict';
// CI-only database isolation. No host data mounts or host security-policy changes.
const { spawn } = require('node:child_process');
const { randomBytes } = require('node:crypto');
const mysql = require('../../api/node_modules/mysql2/promise');
const IMAGE = 'mysql:8.0.46@sha256:7dcddc01f13bab2f15cde676d44d01f61fc9f99fe7785e86196dfc07d358ae2b';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function startOwnedLinuxMysql({ password, port }) {
  if (process.platform !== 'linux' || process.env.GITHUB_ACTIONS !== 'true' ||
      !/^[a-f0-9]{72}$/.test(password) || !Number.isInteger(port) || port < 1024 || port > 65535) throw Error('OWNED_LINUX_MYSQL_REQUIRED');
  const owner = randomBytes(16).toString('hex'), name = 'astha-native-' + owner;
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => ['PATH','HOME','USER','LANG','TMPDIR'].includes(key)));
  const dockerArgs = ['--host','unix:///var/run/docker.sock'];
  function command(args, timeout = 15000) {
    return new Promise((resolve,reject) => {
      const child = spawn('docker',[...dockerArgs,...args],{ env, stdio: ['ignore','pipe','ignore'] });
      let output = '';
      child.stdout.on('data',data => { if(output.length<3000)output+=data; });
      const timer = setTimeout(()=>{child.kill();reject(Error('OWNED_CONTAINER_COMMAND_TIMEOUT'));},timeout);
      child.once('error',error=>{clearTimeout(timer);reject(error);});
      child.once('close',code=>{clearTimeout(timer);resolve({code,output:output.trim()});});
    });
  }
  let processHandle, closed = false;
  async function close() {
    if(closed)return;closed=true;
    const listed = await command(['ps','--all','--filter','name='+name,'--format','{{.Names}}']);
    if(listed.code!==0)throw Error('OWNED_CONTAINER_QUERY_FAILED');
    if(listed.output){
      if(listed.output!==name)throw Error('OWNED_CONTAINER_CLEANUP_REJECTED');
      const label = await command(['inspect','--format','{{ index .Config.Labels "astha.native.qa" }}',name]);
      if(label.code!==0)throw Error('OWNED_CONTAINER_QUERY_FAILED');
      if(label.output!==owner)throw Error('OWNED_CONTAINER_CLEANUP_REJECTED');
      const removed = await command(['rm','--force',name],30000);
      if(removed.code!==0)throw Error('OWNED_CONTAINER_CLEANUP_FAILED');
    }
    if(processHandle?.exitCode===null){
      await Promise.race([new Promise(resolve=>processHandle.once('close',resolve)),delay(5000)]);
      if(processHandle.exitCode===null)processHandle.kill();
    }
  }
  try {
    // Password is passed through the process environment, never in argv/logs.
    processHandle = spawn('docker',[...dockerArgs,'run','--rm','--name',name,
      '--label','astha.native.qa='+owner,'--network','host',
      '--tmpfs','/var/lib/mysql:rw,noexec,nosuid,size=768m',
      '-e','MYSQL_ROOT_PASSWORD','-e','MYSQL_ROOT_HOST',IMAGE,
      '--bind-address=127.0.0.1','--port='+port,'--mysqlx=0','--skip-name-resolve','--skip-log-bin'],
    { env:{...env,MYSQL_ROOT_PASSWORD:password,MYSQL_ROOT_HOST:'127.0.0.1'},stdio:'ignore' });
    processHandle.on('error',()=>{});
    const until = Date.now()+180000;
    while(Date.now()<until){
      if(processHandle.exitCode!==null)throw Error('OWNED_MYSQL_CONTAINER_EXITED');
      try {
        const root = await mysql.createConnection({host:'127.0.0.1',port,user:'root',password,multipleStatements:false,flags:'-LOCAL_FILES',connectTimeout:1000});
        return { root, processHandle, close };
      } catch (_) { await delay(500); }
    }
    throw Error('OWNED_MYSQL_CONTAINER_TIMEOUT');
  } catch(error) { await close();throw error; }
}
module.exports = { startOwnedLinuxMysql, IMAGE };
