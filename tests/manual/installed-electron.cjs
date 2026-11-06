'use strict';
// Explicit packaged-runtime test. Uses only a newly-created QA userData profile.
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict');
const {_electron}=require(process.env.ASTHA_PLAYWRIGHT_PACKAGE||path.resolve(__dirname,'../.runtime/ui-python/playwright/driver/package'));
async function main(){
 const install=path.join(process.env.USERPROFILE,'AppData/Local/ASTHA-RAVEN-QA/installation-2026-11-06/ASTHA RAVEN');
 const executablePath=path.join(install,'ASTHA RAVEN.exe');await fs.access(executablePath);
 const qa=path.join(process.env.USERPROFILE,'ASTHA-RAVEN-QA');await fs.mkdir(qa,{recursive:true});
 const profile=await fs.mkdtemp(path.join(qa,'packaged-profile-'));let desktop;
 const evidence=path.resolve(__dirname,'../.runtime/installer-qa');await fs.mkdir(evidence,{recursive:true});
 try{
  const env=Object.fromEntries(Object.entries(process.env).filter(([k,v])=>k!=='ELECTRON_RUN_AS_NODE'&&typeof v==='string'));
  desktop=await _electron.launch({executablePath,args:['--user-data-dir='+profile],env,timeout:40000});
  const state=await desktop.evaluate(({app,BrowserWindow})=>({packaged:app.isPackaged,userData:app.getPath('userData'),windows:BrowserWindow.getAllWindows().map(w=>{const p=w.webContents.getLastWebPreferences();return{sandbox:p.sandbox,contextIsolation:p.contextIsolation,nodeIntegration:p.nodeIntegration,webSecurity:p.webSecurity};})}));
  assert.equal(path.resolve(state.userData),path.resolve(profile));assert.equal(state.packaged,true);
  const page=await desktop.firstWindow(),errors=[];page.on('pageerror',e=>errors.push(e.name));
  await page.waitForURL('https://136.111.89.192/app/login.html',{timeout:40000});
  await page.locator('#email').waitFor();await page.locator('#password').waitFor();
  await page.screenshot({path:path.join(evidence,'installed-login.png'),fullPage:true});
  assert.ok(state.windows.every(w=>w.sandbox&&w.contextIsolation&&w.webSecurity&&!w.nodeIntegration));assert.equal(errors.length,0);
  const result={status:'INSTALLED_ELECTRON_PASSED',packaged:true,installerLocation:install,isolatedProfile:true,realHttps:true,secureWindow:true,loginForm:true,pageErrors:0};
  await fs.writeFile(path.join(evidence,'result.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
 }finally{
  await desktop?.close();
  const actual=await fs.realpath(profile),parent=await fs.realpath(qa);
  if(path.dirname(actual)!==parent||!path.basename(actual).startsWith('packaged-profile-'))throw Error('QA_PROFILE_CLEANUP_REJECTED');
  await fs.rm(actual,{recursive:true,force:true,maxRetries:5,retryDelay:200});
 }
}
if(require.main===module)main().catch(e=>{console.error('INSTALLED_ELECTRON_FAILED',e.code||e.name);process.exitCode=1;});
