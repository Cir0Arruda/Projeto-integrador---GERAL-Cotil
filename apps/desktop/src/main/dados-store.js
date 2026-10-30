'use strict';
const fs = require('node:fs');
const path = require('node:path');
const DEFAULTS = Object.freeze({ tema: 'system', mostrarIndicadorSincronizacao: true, sincronizacaoAutomatica: true });
let dataPath = null;
function configureDirectory(directory) {
  if (!path.isAbsolute(directory)) throw Error('DESKTOP_DATA_PATH_INVALID');
  dataPath = path.join(directory, 'preferences.json');
}
function validate(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).some(key => key !== 'preferenciasDesktop')) throw Error('DESKTOP_PREFERENCES_INVALID');
  const prefs = value.preferenciasDesktop;
  if (!prefs || typeof prefs !== 'object' || Array.isArray(prefs) ||
      Object.keys(prefs).some(key => !Object.hasOwn(DEFAULTS, key))) throw Error('DESKTOP_PREFERENCES_INVALID');
  if (prefs.tema !== undefined && !['system','light','dark','dark-industrial'].includes(prefs.tema)) throw Error('DESKTOP_PREFERENCES_INVALID');
  for (const key of ['mostrarIndicadorSincronizacao','sincronizacaoAutomatica']) {
    if (prefs[key] !== undefined && typeof prefs[key] !== 'boolean') throw Error('DESKTOP_PREFERENCES_INVALID');
  }
  return prefs;
}
function lerDados() {
  if (!dataPath || !fs.existsSync(dataPath)) return { preferenciasDesktop: { ...DEFAULTS } };
  try {
    if (fs.statSync(dataPath).size > 4096) throw Error();
    const value = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
    return { preferenciasDesktop: { ...DEFAULTS, ...validate(value) } };
  } catch (_) { throw Error('DESKTOP_PREFERENCES_UNAVAILABLE'); }
}
function salvarDados(value) {
  const next = { preferenciasDesktop: { ...lerDados().preferenciasDesktop, ...validate(value) } };
  if (!dataPath) throw Error('DESKTOP_PREFERENCES_NOT_INITIALIZED');
  fs.mkdirSync(path.dirname(dataPath), { recursive: true, mode: 0o700 });
  const temporary = dataPath + '.tmp';
  try {
    fs.writeFileSync(temporary, JSON.stringify(next), { encoding: 'utf8', mode: 0o600 });
    fs.renameSync(temporary, dataPath); // Synchronous writes serialize IPC requests; rename publishes atomically.
  } finally { fs.rmSync(temporary, { force: true }); }
  return next;
}
module.exports = { configureDirectory, lerDados, salvarDados };
