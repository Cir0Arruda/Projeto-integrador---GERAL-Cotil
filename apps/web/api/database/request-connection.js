'use strict';
const safeErrorLog = require('../security/safe-error-log');

// Express 4 does not forward rejected async handlers automatically. Acquisition
// must finish with a response even before a route's transaction try/finally.
async function acquireConnection(pool, res) {
  try { return await pool.getConnection(); }
  catch (error) {
    safeErrorLog('[DB_ACQUIRE]', error);
    res.status(503).json({ error: 'Banco de dados temporariamente indisponível. Tente novamente.' });
    return null;
  }
}

async function rollbackConnection(connection) {
  try { await connection.rollback(); }
  catch (error) {
    // A failed rollback must not return a possibly active transaction to the pool
    // or prevent the handler from sending its original, sanitized error response.
    try { connection.destroy?.(); } catch (_) {}
    safeErrorLog('[DB_ROLLBACK]', error);
  }
}

module.exports = { acquireConnection, rollbackConnection };
