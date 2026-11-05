/* ============================================================
   ASTHA RAVEN ? API Client (api.js)
   Fetch wrapper with auth headers, error handling
   ============================================================ */

const API = {
  _pendingReads: new Map(),
  _readSession: null,
  _dataRevision: 0,
  _redirectingOn401: false,
  _expiredToken: null,
  // Base URL da API ? detecta dinamicamente a origem
  BASE_URL: (function() {
    if (typeof window !== 'undefined' && window.location) {
      if (window.location.protocol === 'file:') {
        return 'http://localhost:3000/api';
      }
      const hostname = window.location.hostname || 'localhost';
      const port = window.location.port;
      if (['localhost', '127.0.0.1', '::1', '[::1]'].includes(hostname) && ['4173', '5500', '5501'].includes(port)) {
        const apiHostname = hostname.includes(':') && !hostname.startsWith('[') ? `[${hostname}]` : hostname;
        return `http://${apiHostname}:3000/api`;
      }
    }
    return '/api';
  })(),

  async request(endpoint, options = {}) {
    const token = localStorage.getItem('astha_token');
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || '';

    const config = {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...(token && { 'Authorization': `Bearer ${token}` }),
        ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
        ...options.headers,
      },
    };

    const controller = options.method === 'GET' && !options.signal ? new AbortController() : null;
    const timeout = controller ? setTimeout(() => controller.abort(), 20000) : null;
    if (controller) config.signal = controller.signal;
    try {
      const response = await fetch(`${this.BASE_URL}${endpoint}`, config);
      if (localStorage.getItem('astha_token') !== token) {
        return { success: false, status: 409, error: 'A sessão mudou. Atualize os dados para continuar.' };
      }
      let data = {};
      try { data = response.ok && options.responseType === 'text' ? { content: await response.text() } : await response.json(); } catch(e) {}
      // Headers can arrive well before the body. Another tab may replace the
      // login while decoding, so authorize publication and expiry handling again.
      if (localStorage.getItem('astha_token') !== token) {
        return { success: false, status: 409, error: 'A sessão mudou. Atualize os dados para continuar.' };
      }

      if (response.status === 401 && endpoint !== '/auth/login' && !endpoint.startsWith('/auth/oauth/')) {
        // Session expired ? clear token and redirect to login
        if (!this._redirectingOn401 || this._expiredToken !== token) {
          this._redirectingOn401 = true;
          this._expiredToken = token;
          localStorage.removeItem('astha_token');
          localStorage.removeItem('astha_user');
          sessionStorage.setItem('ASTHA_redirect', window.location.pathname + window.location.search);
          if (typeof showToast === 'function') {
            showToast('Sessão expirada. Por favor, faça login novamente.', 'error');
          }
          setTimeout(() => {
            if (!localStorage.getItem('astha_token') && this._expiredToken === token) window.location.href = '/app/login.html';
          }, 1200);
        }
        return { success: false, status: 401, error: data?.error || 'Sessão expirada' };
      }

      if (!response.ok) {
        if (response.status === 429) {
          const retryAfter = Math.max(1, Number(response.headers.get('Retry-After')) || 60);
          return { success: false, status: 429, retryAfter, error: `Muitas solicitações em sequência. Aguarde ${retryAfter} segundos e tente novamente.` };
        }
        const errMsg = data?.error || data?.message || `HTTP ${response.status}`;
        return { success: false, status: response.status, error: errMsg };
      }
      // A refresh after a confirmed write must not reuse a GET started before
      // that write. Existing consumers can finish; subsequent reads fetch anew.
      if (!['GET', 'HEAD', 'OPTIONS'].includes(String(config.method || 'GET').toUpperCase())) {
        this._dataRevision++;
        this._pendingReads.clear();
      }
      return { success: true, ...data, data };
    } catch (error) {
      console.error(`API Error [${endpoint}]:`, error);
      return { success: false, error: error.name === 'AbortError' ? 'O carregamento demorou demais. Tente novamente.' : error.message };
    } finally { if (timeout) clearTimeout(timeout); }
  },

  get(endpoint) {
    const session = localStorage.getItem('astha_token');
    if (session !== this._readSession) { this._pendingReads.clear(); this._readSession = session; }
    if (this._pendingReads.has(endpoint)) return this._pendingReads.get(endpoint);
    const revision = this._dataRevision;
    const pending = this.request(endpoint, { method: 'GET' }).then(result => {
      // A slow pre-write consumer must not overwrite a newer stock view either.
      // Join the current read (or fetch once more) under the same session.
      if (result.success && revision !== this._dataRevision && localStorage.getItem('astha_token') === session) return this.get(endpoint);
      return result;
    }).finally(() => {
      if (this._pendingReads.get(endpoint) === pending) this._pendingReads.delete(endpoint);
    });
    this._pendingReads.set(endpoint, pending);
    return pending;
  },
  post(endpoint, body) { return this.request(endpoint, { method: 'POST', body: JSON.stringify(body) }); },
  put(endpoint, body) { return this.request(endpoint, { method: 'PUT', body: JSON.stringify(body) }); },
  delete(endpoint) { return this.request(endpoint, { method: 'DELETE' }); },
};

