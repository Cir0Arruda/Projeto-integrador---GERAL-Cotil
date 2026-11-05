'use strict';

// mysql2 errors can include the interpolated SQL, uploaded bytes and private
// fields. Keep an operational event/code without serializing the error object.
function safeErrorLog(event, error) {
  const code = typeof error?.code === 'string' &&
    /^(?:ER_[A-Z0-9_]{1,64}|E[A-Z0-9_]{1,64})$/.test(error.code)
    ? error.code : 'UNEXPECTED_ERROR';
  console.error(event, code);
}

module.exports = safeErrorLog;
