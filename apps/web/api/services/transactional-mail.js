'use strict';
const nodemailer = require('nodemailer');

// One mailbox only. Never accept headers, transport URLs, attachments or a sender
// supplied by an HTTP client. SMTP credentials belong exclusively to the server.
function mailbox(value) {
  if (typeof value !== 'string' || value.length > 254 ||
      !/^[a-zA-Z0-9.!#$%&'*+\-/=?^_`{|}~]+@[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,63}$/.test(value)) {
    throw Object.assign(Error('Invalid mailbox'), { code: 'MAIL_ADDRESS_INVALID' });
  }
  return value.toLowerCase();
}
function configuration(env) {
  if (env.MAIL_ENABLED !== 'true') return null;
  const port = Number(env.MAIL_PORT || 587), host = env.MAIL_HOST || '';
  if (![465, 587].includes(port) || host.length > 253 ||
      !/^[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?$/.test(host) ||
      !env.MAIL_USER || !env.MAIL_PASSWORD || /[\r\n\0]/.test(env.MAIL_USER)) throw Error('MAIL_CONFIG_INVALID');
  return { from: mailbox(env.MAIL_FROM), options: {
    host, port, secure: port === 465, requireTLS: port !== 465,
    tls: { rejectUnauthorized: true, minVersion: 'TLSv1.2', servername: host },
    auth: { user: env.MAIL_USER, pass: env.MAIL_PASSWORD },
    connectionTimeout: 8000, greetingTimeout: 8000, socketTimeout: 10000, dnsTimeout: 5000,
    disableFileAccess: true, disableUrlAccess: true, maxRecipients: 1,
    logger: false, debug: false,
  } };
}
function createMailer({ env = process.env, transportFactory = nodemailer.createTransport,
  onFailure = () => console.warn('TRANSACTIONAL_MAIL_FAILED') } = {}) {
  let settings, transport, active = 0;
  const queue = [], waiters = [];
  try { settings = configuration(env); } catch (_) { settings = null; }
  function enabled() { return !!settings; }
  async function send(kind, { to, code, organization, expiresAt }) {
    if (!enabled()) throw Error('MAIL_UNAVAILABLE');
    const recipient = mailbox(to);
    if (typeof code !== 'string' || !(kind === 'recovery' ? /^[\w-]{22}$/ : /^[A-F0-9]{8}$/).test(code)) throw Error('MAIL_CODE_INVALID');
    if (!transport) transport = transportFactory(settings.options);
    const text = kind === 'recovery'
      ? `Você solicitou a recuperação de acesso ao ASTHA RAVEN.\n\nCódigo: ${code}\n\nVálido por 15 minutos e utilizável uma única vez. Informe o código na tela Recuperar acesso do aplicativo. Não compartilhe este código. Se você não fez esta solicitação, ignore a mensagem. Sua senha não foi alterada.\n`
      : `Você recebeu um convite para ${String(organization || 'uma organização no ASTHA RAVEN').replace(/[\x00-\x1f\x7f]/g, ' ').slice(0, 120)}.\n\nCódigo: ${code}\n\nVálido até ${new Date(expiresAt).toISOString()}. Informe o código no cadastro ou na opção Entrar em uma organização do ASTHA RAVEN. Se você não esperava este convite, ignore a mensagem.\n`;
    const result = await transport.sendMail({
      from: { name: 'ASTHA RAVEN', address: settings.from }, to: recipient,
      envelope: { from: settings.from, to: [recipient] },
      subject: kind === 'recovery' ? 'ASTHA RAVEN — recuperação de acesso' : 'ASTHA RAVEN — convite para sua equipe',
      text, disableFileAccess: true, disableUrlAccess: true,
    });
    if (!result.accepted?.some(address => String(address).toLowerCase() === recipient) || result.rejected?.length) throw Error('MAIL_NOT_ACCEPTED');
  }
  function pump() {
    while (active < 2 && queue.length) {
      const work = queue.shift(); active++;
      Promise.resolve().then(() => work(data => send('recovery', data)))
        .catch(() => { try { onFailure(); } catch (_) { /* Never log the SMTP error or payload. */ } })
        .finally(() => { active--; pump(); if (!active && !queue.length) waiters.splice(0).forEach(resolve => resolve()); });
    }
  }
  // Requests for existing and absent accounts receive the same response before
  // DB/SMTP work begins. The bounded volatile queue never persists raw codes.
  function enqueueRecovery(work) {
    if (!enabled() || active + queue.length >= 8) return false;
    queue.push(work); setImmediate(pump); return true;
  }
  function idle() { return active || queue.length ? new Promise(resolve => waiters.push(resolve)) : Promise.resolve(); }
  return { enabled, enqueueRecovery, idle,
    sendInvitation: data => send('invitation', data),
    close: async () => { await idle(); transport?.close?.(); },
  };
}
module.exports = { mailbox, configuration, createMailer, mailer: createMailer() };
