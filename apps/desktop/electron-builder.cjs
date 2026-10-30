'use strict';
module.exports = {
  appId: 'com.asthareven.wms', productName: 'ASTHA RAVEN',
  directories: { output: '../dist/desktop' }, asar: true,
  files: [
    'package.json', 'src/main/index.js', 'src/main/runtime.js',
    'src/main/window-security.js', 'src/main/preload.js',
    'src/main/desktop-ipc.js', 'src/main/dados-store.js',
    'src/main/security/client-deployment.js', 'src/renderer/images/app_icon.png',
    '!**/.env', '!**/.env.*', '!**/.local/**', '!**/*.dpapi',
    '!**/*.pem', '!**/*.key', '!**/*.p12', '!**/*.pfx', '!**/*.log',
    '!**/preferences.json', '!**/dados.json', '!**/node_modules/**'
  ],
  win: { target: 'nsis', icon: 'src/renderer/images/app_icon.png' },
  nsis: { oneClick: false, perMachine: false, allowToChangeInstallationDirectory: true,
    include: 'installer/brand.nsh',
    installerHeader: 'installer/header.bmp',
    installerSidebar: 'installer/installer-sidebar.bmp',
    uninstallerSidebar: 'installer/uninstaller-sidebar.bmp',
    installerLanguages: ['pt_BR'], language: '1046',
    deleteAppDataOnUninstall: false, createDesktopShortcut: true }
};
