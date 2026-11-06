(function (root, factory) {
  'use strict';
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.WmsLiveStock = api;
})(typeof window === 'undefined' ? globalThis : window, function () {
  'use strict';
  function create(options) {
    const interval = 5000, setTimer = options.setTimer || setTimeout, clearTimer = options.clearTimer || clearTimeout;
    const now = options.now || Date.now, view = options.window || window, doc = options.document || document;
    let timer = null, running = false, stopped = false, started = false, queued = false, suspended = false;
    let identity, failures = 0, nextAllowed = 0;
    const identityOf = value => value && JSON.stringify([value.token, value.orgId, value.userId]);
    const key = value => JSON.stringify(value);
    const status = state => options.status?.(state);
    function cancel() { if (timer !== null) clearTimer(timer); timer = null; }
    function context() {
      const value = options.context();
      if (started && identityOf(value) !== identity) {
        dispose(); options.identityChanged?.(); status('session-changed'); return null;
      }
      return value?.token && value.orgId && value.warehouseId ? value : null;
    }
    function visible() { return !stopped && !suspended && options.visible(); }
    function schedule() {
      cancel();
      if (visible() && context()) timer = setTimer(() => { timer = null; void refresh(); }, Math.max(interval, nextAllowed - now()));
    }
    async function refresh() {
      cancel();
      if (!visible()) { status('paused'); return; }
      const snapshot = context(); if (!snapshot || stopped) return;
      if (running) { queued = true; return; }
      if (now() < nextAllowed || options.blocked()) { schedule(); return; }
      running = true;
      try {
        const result = await options.read(snapshot);
        if (stopped || !visible() || !context() || key(snapshot) !== key(options.context()) || options.blocked()) return;
        if (result?.success && Array.isArray(result.data)) {
          options.publish(result.data); failures = 0; nextAllowed = 0; status('current');
        } else {
          failures++;
          nextAllowed = now() + (result?.status === 429 ? Math.max(interval, Math.min(120000, (Number(result.retryAfter) || 60) * 1000)) : Math.min(60000, interval * 2 ** Math.min(failures, 4)));
          status('unavailable');
        }
      } catch (_) {
        if (stopped) return;
        failures++; nextAllowed = now() + Math.min(60000, interval * 2 ** Math.min(failures, 4)); status('unavailable');
      } finally {
        running = false;
        if (queued) { queued = false; void refresh(); } else schedule();
      }
    }
    const onWake = () => { void refresh(); };
    const onHide = event => { suspended = true; cancel(); if (!event.persisted) dispose(); };
    const onShow = () => { suspended = false; void refresh(); };
    function start() {
      if (started || stopped) return;
      identity = identityOf(options.context()); started = true;
      view.addEventListener('focus', onWake);
      view.addEventListener('astha-wms-view', onWake);
      view.addEventListener('storage', onWake);
      view.addEventListener('pagehide', onHide);
      view.addEventListener('pageshow', onShow);
      doc.addEventListener('visibilitychange', onWake);
      void refresh();
    }
    function dispose() {
      stopped = true; queued = false; cancel();
      view.removeEventListener('focus', onWake);
      view.removeEventListener('astha-wms-view', onWake);
      view.removeEventListener('storage', onWake);
      view.removeEventListener('pagehide', onHide);
      view.removeEventListener('pageshow', onShow);
      doc.removeEventListener('visibilitychange', onWake);
    }
    return {start, refresh, dispose};
  }
  return {create};
});
