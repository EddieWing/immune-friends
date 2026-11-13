(() => {
  const attemptKey = 'microcosm-isolation-attempt';
  const path = (variant) => `./${variant}/index.html${location.search}${location.hash}`;
  const open = (variant) => location.replace(path(variant));
  const sharedMemoryAvailable = () => {
    if (!window.crossOriginIsolated || typeof SharedArrayBuffer === 'undefined') return false;
    try { return new WebAssembly.Memory({initial: 1, maximum: 1, shared: true}).buffer instanceof SharedArrayBuffer; }
    catch { return false; }
  };
  const safeGet = () => { try { return sessionStorage.getItem(attemptKey); } catch { return 'unavailable'; } };
  const safeSet = (value) => { try { sessionStorage.setItem(attemptKey, value); return true; } catch { return false; } };
  const safeClear = () => { try { sessionStorage.removeItem(attemptKey); } catch {} };
  (async () => {
    if (sharedMemoryAvailable()) { safeClear(); open('threaded'); return; }
    if (!isSecureContext || !('serviceWorker' in navigator) || safeGet()) { safeClear(); open('single'); return; }
    if (!safeSet('1')) { open('single'); return; }
    try {
      const registration = await navigator.serviceWorker.register('./isolation-sw.js', {scope: './'});
      await Promise.race([navigator.serviceWorker.ready, new Promise((_, reject) => setTimeout(() => reject(new Error('Service worker timeout')), 5000))]);
      if (!navigator.serviceWorker.controller) {
        await Promise.race([new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, {once:true})), new Promise((_, reject) => setTimeout(() => reject(new Error('Service worker control timeout')), 5000))]);
      }
      if (registration.active && navigator.serviceWorker.controller) location.reload();
      else { safeClear(); open('single'); }
    } catch { safeClear(); open('single'); }
  })();
})();
