'use strict';
function sameOrigin(value, origin) {
  try { const u = new URL(value); return !u.username && !u.password && u.origin === origin; }
  catch { return false; }
}
function applyWindowSecurity(win, deployment, { shell, dialog }) {
  const contents = win.webContents;
  contents.session.setPermissionRequestHandler((_wc, _permission, callback) => callback(false));
  contents.session.setPermissionCheckHandler(() => false);
  const guard = (event, target) => { if (!sameOrigin(event.url ?? target, deployment.url)) event.preventDefault(); };
  for (const name of ['will-navigate', 'will-redirect', 'will-frame-navigate']) contents.on(name, guard);
  contents.on('will-attach-webview', event => event.preventDefault());
  let confirming = false;
  contents.setWindowOpenHandler(({ url }) => {
    let target;
    try { target = new URL(url); } catch { return { action: 'deny' }; }
    if (target.protocol !== 'https:' || target.username || target.password || confirming) return { action: 'deny' };
    confirming = true;
    Promise.resolve(dialog.showMessageBox(win, {
      type: 'question', title: 'Abrir no navegador?',
      message: 'Deseja abrir este endereço no navegador do sistema?',
      detail: target.origin, buttons: ['Cancelar', 'Abrir'], defaultId: 0, cancelId: 0
    })).then(result => {
      if (result.response === 1 && !win.isDestroyed()) return shell.openExternal(target.href);
    }).catch(() => {}).finally(() => { confirming = false; });
    return { action: 'deny' };
  });
}
module.exports = { sameOrigin, applyWindowSecurity };
