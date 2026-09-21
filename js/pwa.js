import { UI } from './ui.js';

// ============ PWA: service worker, status koneksi, reset cache ============

const CACHE_RESET_TIMEOUT_MS = 8000;

export function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) return;

  // Toast "versi baru" hanya untuk pembaruan, bukan pemasangan pertama.
  const hadController = !!navigator.serviceWorker.controller;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (hadController) {
      UI.toast('Versi baru terpasang. Muat ulang untuk memakainya.', { type: 'info', duration: 8000 });
    }
  });

  navigator.serviceWorker
    .register('./sw.js', { updateViaCache: 'none' })
    .catch((err) => console.warn('[PWA] Service worker gagal didaftarkan:', err));
}

export function watchConnectivity() {
  window.addEventListener('offline', () => {
    UI.toast('Anda offline. Aplikasi tetap bisa dipakai; data tersimpan di perangkat.', { type: 'warning', duration: 5000 });
  });
  window.addEventListener('online', () => {
    UI.toast('Kembali online.', { type: 'success' });
  });
}

export function isOnline() {
  return navigator.onLine;
}

// True bila service worker sudah aktif mengendalikan halaman ini (siap offline).
export function isOfflineReady() {
  return 'serviceWorker' in navigator && !!navigator.serviceWorker.controller;
}

// Hapus cache aplikasi (BUKAN data akun/stok, yang ada di database).
// Lewat service worker bila aktif; jika tidak, hapus langsung dari halaman.
export async function clearAppCache() {
  const registration = 'serviceWorker' in navigator ? await navigator.serviceWorker.getRegistration() : null;
  const worker = registration && registration.active;

  if (worker) {
    return new Promise((resolve) => {
      const channel = new MessageChannel();
      const timer = setTimeout(() => resolve({ ok: false, precached: 0 }), CACHE_RESET_TIMEOUT_MS);
      channel.port1.onmessage = (event) => {
        clearTimeout(timer);
        resolve(event.data);
      };
      worker.postMessage({ type: 'CLEAR_CACHE' }, [channel.port2]);
    });
  }

  if (typeof caches === 'undefined') return { ok: false, precached: 0 };
  const keys = await caches.keys();
  await Promise.all(keys.map((key) => caches.delete(key)));
  return { ok: true, precached: 0 };
}
