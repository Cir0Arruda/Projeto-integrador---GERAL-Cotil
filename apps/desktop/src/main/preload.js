'use strict';

// Narrow renderer bridge; every invocation is authorized in desktop-ipc.js.

const { contextBridge, ipcRenderer } = require('electron');

const desktopApi = Object.freeze({
  isDesktop: true,
  platform: process.platform,

  // Lê apenas preferências locais do aplicativo
  lerDados() {
    return ipcRenderer.invoke('dados:ler');
  },

  // Salva preferências validadas em userData
  salvarDados(novosDados) {
    return ipcRenderer.invoke('dados:salvar', novosDados);
  },

  // Obtém informações do runtime Desktop (porta, perfil ativo, URL)
  getRuntimeInfo() {
    return ipcRenderer.invoke('astha:runtime-info');
  }
});

// Keep the legacy api alias while Web clients migrate to asthaDesktop.
contextBridge.exposeInMainWorld('api', desktopApi);
contextBridge.exposeInMainWorld('asthaDesktop', desktopApi);
