'use strict';
const fs=require('node:fs'),path=require('node:path'),{spawn}=require('node:child_process');
const root=path.resolve(__dirname,'..'),allowed=['analytics','security','ui'];
const groups=process.argv.slice(2).length?process.argv.slice(2):allowed;
if(groups.some(group=>!allowed.includes(group))){console.error('Use: node scripts/test.cjs [analytics|security|ui]');process.exit(2);}
const files=[];
for(const group of [...new Set(groups)])for(const item of fs.readdirSync(path.join(root,'tests',group),{withFileTypes:true}))if(item.isFile()&&/\.test\.(?:js|cjs)$/.test(item.name))files.push(path.join('tests',group,item.name));
files.sort();
console.log('Running '+files.length+' test files. Integration tests and local databases are excluded.');
const child=spawn(process.execPath,['--test','--test-concurrency=2','--test-timeout=60000',...files],{cwd:root,stdio:'inherit',shell:false,windowsHide:true});
child.on('error',()=>{console.error('Could not start the test runner.');process.exitCode=1;});
child.on('exit',code=>{process.exitCode=code??1;});
