'use strict';
const path = require('node:path');
const { fork } = require('node:child_process');
const { desktopServer } = require('./security/client-deployment');
const store = require('./dados-store');
const { registerDesktopIpc } = require('./desktop-ipc');
const { applyWindowSecurity } = require('./window-security');
function startDesktop({ app, BrowserWindow, dialog, shell, ipcMain }, options = {}) {
  const env = options.env || process.env, args = options.args || process.argv.slice(1);
  const spawnApi = options.fork || fork;
  let win = null, child = null, timer = null, ready = false, quitting = false, errorDialog = false;
  let deployment;
  try { deployment = desktopServer(env.ASTHA_SERVER_URL, { args, env, port: env.ASTHA_LOCAL_PORT || '3001' }); }
  catch { deployment = null; }
  if (!app.requestSingleInstanceLock()) { app.quit(); return; }
  app.enableSandbox();
  function stopApi() {
    if (timer) clearTimeout(timer);
    timer = null;
    const owned = child; child = null;
    if (owned && !owned.killed) owned.kill();
  }
  function load() {
    if (!win || win.isDestroyed()) return;
    Promise.resolve(win.loadURL(deployment.url)).catch(() => {});
  }
  async function connectionFailed() {
    if (errorDialog || quitting || !win || win.isDestroyed()) return;
    errorDialog = true;
    try {
      const result = await dialog.showMessageBox(win, {
        type: 'warning', title: 'Conexão com o ASTHA',
        message: 'Não foi possível abrir o servidor do ASTHA.',
        detail: 'Confira a conexão e a disponibilidade do servidor. A validação HTTPS continua ativa.',
        buttons: ['Tentar novamente', 'Fechar'], defaultId: 0, cancelId: 1
      });
      if (quitting || !win || win.isDestroyed()) return;
      if (result.response === 0) load(); else app.quit();
    } catch { app.quit(); }
    finally { errorDialog = false; }
  }
  function createWindow() {
    if (quitting || !deployment) return;
    if (win && !win.isDestroyed()) { if (win.isMinimized()) win.restore(); win.focus(); return; }
    win = new BrowserWindow({
      width: 1360, height: 860, minWidth: 1024, minHeight: 680,
      title: 'ASTHA RAVEN', backgroundColor: '#f4f5f8', autoHideMenuBar: true,
      icon: path.join(__dirname, '../renderer/images/app_icon.png'),
      webPreferences: {
        nodeIntegration: false, contextIsolation: true, sandbox: true, webSecurity: true,
        allowRunningInsecureContent: false, webviewTag: false,
        preload: path.join(__dirname, 'preload.js')
      }
    });
    win.setMenuBarVisibility(false);
    applyWindowSecurity(win, deployment, { shell, dialog });
    win.webContents.on('did-fail-load', (_event, code, _description, _url, mainFrame) => {
      if (mainFrame && code !== -3) void connectionFailed();
    });
    win.webContents.on('render-process-gone', () => { void connectionFailed(); });
    win.on('closed', () => { win = null; });
    load();
  }
  registerDesktopIpc({ ipcMain, getWindow: () => win, getDeployment: () => deployment,
    getProfile: () => deployment?.local ? 'local' : 'vps' });
  app.on('second-instance', () => { if (win && !win.isDestroyed()) { if (win.isMinimized()) win.restore(); win.focus(); } });
  app.on('ready', () => {
    store.configureDirectory(app.getPath('userData'));
    if (!deployment || (app.isPackaged && deployment.local)) {
      dialog.showErrorBox('Configuração inválida', 'Use uma origem HTTPS válida. Recuperação local está disponível somente no ambiente de desenvolvimento.');
      app.quit(); return;
    }
    if (!deployment.local) { ready = true; createWindow(); return; }
    let failureHandled = false;
    function failed() {
      if (quitting || failureHandled) return;
      failureHandled = true;
      dialog.showErrorBox('Recuperação local indisponível', 'O servidor local não iniciou ou foi encerrado. Confira a configuração de recuperação.');
      stopApi(); app.quit();
    }
    try {
      child = spawnApi(path.join(__dirname, 'api-bootstrap.js'), ['--profile=local'], {
        cwd: __dirname, env: { ...env, ASTHA_LOCAL_PORT: env.ASTHA_LOCAL_PORT || '3001', ELECTRON_RUN_AS_NODE: '1' },
        stdio: ['ignore', 'inherit', 'inherit', 'ipc']
      });
      timer = setTimeout(failed, 30000); timer.unref();
      child.on('error', failed);
      child.on('message', message => {
        if (ready || failureHandled || message?.type !== 'astha-api-ready') return;
        const port = String(message.port || '');
        if (!/^\d{1,5}$/.test(port) || Number(port) < 1 || Number(port) > 65535) return;
        clearTimeout(timer); timer = null;
        deployment.url = 'http://localhost:' + Number(port); ready = true; createWindow();
      });
      child.on('exit', () => { child = null; failed(); });
    } catch { failed(); }
  });
  app.on('before-quit', () => { quitting = true; stopApi(); });
  app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
  app.on('activate', () => { if (ready) createWindow(); });
}
module.exports = { startDesktop };
