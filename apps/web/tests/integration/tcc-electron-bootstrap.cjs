'use strict';
// Only the owned local QA server's readiness is injected. Actual desktop runtime,
// BrowserWindow, preload, IPC, navigation/permission guards remain unchanged.
const fs = require('node:fs');
const path = require('node:path');
const {EventEmitter} = require('node:events');
const electron = require('electron');
const runtime = fs.realpathSync(path.resolve(__dirname, '../.runtime'));
const profile = fs.realpathSync(process.env.ASTHA_QA_PROFILE || '');
if (path.dirname(profile) !== runtime || !path.basename(profile).startsWith('tcc-electron-profile-')) throw Error('QA_PROFILE_REQUIRED');
electron.app.setPath('userData', profile);
electron.app.setName('ASTHA RAVEN QA');
const desktopRoot = process.env.ASTHA_TCC_DESKTOP_ROOT || path.resolve(__dirname, '../../electron');
require(path.join(desktopRoot, 'src/main/runtime')).startDesktop(electron, {
  env: {...process.env, NODE_ENV: 'test', ASTHA_LOCAL_PORT: '3001'},
  args: ['--profile=backup'],
  fork: () => {
    const child = new EventEmitter();
    child.kill = () => { child.killed = true; child.emit('exit', 0); };
    setImmediate(() => child.emit('message', {type: 'astha-api-ready', port: '3001'}));
    return child;
  },
});
