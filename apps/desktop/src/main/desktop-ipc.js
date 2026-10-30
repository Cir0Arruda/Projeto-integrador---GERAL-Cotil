'use strict';
const store = require('./dados-store');

function registerDesktopIpc({ ipcMain, getWindow, getDeployment, getProfile }) {
  if (!ipcMain || typeof ipcMain.handle !== 'function') return;
  function trusted(event) {
    const win = getWindow(), deployment = getDeployment();
    if (!win || win.isDestroyed() || !deployment || event.sender !== win.webContents ||
        !event.senderFrame || event.senderFrame !== win.webContents.mainFrame) throw Error('IPC_DENIED');
    const url = new URL(event.senderFrame.url);
    if (url.origin !== deployment.url || url.username || url.password) throw Error('IPC_DENIED');
  }
  ipcMain.handle('dados:ler', event => { trusted(event); return store.lerDados(); });
  ipcMain.handle('dados:salvar', (event, value) => { trusted(event); return store.salvarDados(value); });
  ipcMain.handle('astha:runtime-info', event => {
    trusted(event);
    return { isDesktop: true, serverUrl: getDeployment().url, local: getDeployment().local, profile: getProfile() };
  });
}
module.exports = { registerDesktopIpc };
