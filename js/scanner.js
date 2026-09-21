// ============ SCANNER BARCODE (kamera) ============
// Memakai BarcodeDetector bawaan browser bila ada (Chrome Android); jika tidak,
// memakai ZXing yang disimpan lokal (assets/vendor/zxing) dan dimuat saat dibutuhkan.
// Kamera hanya bisa dipakai di HTTPS atau localhost.

const ZXING_SRC = 'assets/vendor/zxing/zxing.min.js';
const NATIVE_FORMATS = ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'itf'];
const FRAME_INTERVAL_MS = 120;
const MAX_FRAME_WIDTH = 720;

const ICON_CLOSE = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>';

let zxingPromise = null;

function loadZxing() {
  if (window.ZXing) return Promise.resolve(window.ZXing);
  if (!zxingPromise) {
    zxingPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = ZXING_SRC;
      script.async = true;
      script.onload = () => (window.ZXing ? resolve(window.ZXing) : reject(new Error('ZXing tidak tersedia')));
      script.onerror = () => {
        zxingPromise = null;
        reject(new Error('ZXing gagal dimuat'));
      };
      document.head.appendChild(script);
    });
  }
  return zxingPromise;
}

// Mengembalikan { engine, detect(source) }. detect() menghasilkan teks barcode atau null.
// `source` boleh <video>, <canvas>, atau <img>.
async function createBarcodeDetector({ preferNative = true } = {}) {
  if (preferNative && 'BarcodeDetector' in window) {
    try {
      const supported = await window.BarcodeDetector.getSupportedFormats();
      const formats = NATIVE_FORMATS.filter((format) => supported.includes(format));
      if (formats.length) {
        const detector = new window.BarcodeDetector({ formats });
        return {
          engine: 'native',
          detect: async (source) => {
            const found = await detector.detect(source);
            return found.length ? found[0].rawValue : null;
          }
        };
      }
    } catch (err) { /* lanjut ke ZXing */ }
  }

  const ZXing = await loadZxing();
  const { BarcodeFormat, DecodeHintType } = ZXing;
  const hints = new Map([
    [DecodeHintType.POSSIBLE_FORMATS, [
      BarcodeFormat.EAN_13, BarcodeFormat.EAN_8, BarcodeFormat.UPC_A, BarcodeFormat.UPC_E,
      BarcodeFormat.CODE_128, BarcodeFormat.CODE_39, BarcodeFormat.ITF
    ]],
    [DecodeHintType.TRY_HARDER, true]
  ]);
  // Pembaca 1D saja (barcode produk): lebih ringan dan tidak berisik di console.
  const reader = new ZXing.MultiFormatOneDReader(hints);
  const canvas = document.createElement('canvas');
  const context = canvas.getContext('2d', { willReadFrequently: true });

  return {
    engine: 'zxing',
    detect: async (source) => {
      const sourceWidth = source.videoWidth || source.naturalWidth || source.width;
      const sourceHeight = source.videoHeight || source.naturalHeight || source.height;
      if (!sourceWidth || !sourceHeight) return null;

      const scale = Math.min(1, MAX_FRAME_WIDTH / sourceWidth);
      canvas.width = Math.round(sourceWidth * scale);
      canvas.height = Math.round(sourceHeight * scale);
      context.drawImage(source, 0, 0, canvas.width, canvas.height);

      try {
        const bitmap = new ZXing.BinaryBitmap(
          new ZXing.HybridBinarizer(new ZXing.HTMLCanvasElementLuminanceSource(canvas))
        );
        return reader.decode(bitmap, hints).getText();
      } catch (err) {
        return null; // ZXing memberi tahu "tidak ada barcode" lewat exception
      }
    }
  };
}

function cameraErrorMessage(err) {
  switch (err && err.name) {
    case 'NotAllowedError':
    case 'SecurityError':
      return 'Izin kamera ditolak. Aktifkan izin kamera untuk situs ini di pengaturan browser, lalu coba lagi.';
    case 'NotFoundError':
    case 'OverconstrainedError':
      return 'Kamera tidak ditemukan di perangkat ini.';
    case 'NotReadableError':
    case 'AbortError':
      return 'Kamera sedang dipakai aplikasi lain. Tutup aplikasi itu lalu coba lagi.';
    default:
      return 'Kamera tidak bisa dibuka. Ketik barcode secara manual.';
  }
}

function buildOverlay() {
  const root = document.createElement('div');
  root.className = 'scanner-overlay';
  root.setAttribute('role', 'dialog');
  root.setAttribute('aria-modal', 'true');
  root.setAttribute('aria-label', 'Scan barcode');
  root.innerHTML = `
    <div class="scanner-top">
      <h2 class="scanner-title">Scan Barcode</h2>
      <button type="button" class="scanner-close" data-scanner-close aria-label="Tutup pemindai">${ICON_CLOSE}</button>
    </div>
    <div class="scanner-stage">
      <video class="scanner-video" playsinline muted autoplay></video>
      <div class="scanner-frame" aria-hidden="true"><span class="scanner-line"></span></div>
    </div>
    <p class="scanner-status" role="status" aria-live="polite">Menyiapkan kamera…</p>
    <button type="button" class="btn btn-secondary btn-large scanner-cancel" data-scanner-close>Batal</button>
  `;
  return {
    root,
    video: root.querySelector('video'),
    status: root.querySelector('.scanner-status'),
    closeButtons: root.querySelectorAll('[data-scanner-close]')
  };
}

let scanning = false;

// Hasil: { code } | { cancelled: true } | { error: 'pesan' }
export function scanBarcode() {
  if (scanning) return Promise.resolve({ cancelled: true });

  if (!window.isSecureContext || !navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    return Promise.resolve({ error: 'Kamera hanya bisa dipakai lewat HTTPS atau localhost. Ketik barcode secara manual.' });
  }

  scanning = true;
  return new Promise((resolve) => {
    const { root, video, status, closeButtons } = buildOverlay();
    const appEl = document.getElementById('app');
    let stream = null;
    let timer = null;
    let finished = false;

    const stopStream = (mediaStream) => {
      if (mediaStream) mediaStream.getTracks().forEach((track) => track.stop());
    };

    const finish = (result) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      stopStream(stream);
      video.srcObject = null;
      document.removeEventListener('keydown', onKeydown);
      window.removeEventListener('hashchange', onHashChange);
      if (appEl) appEl.inert = false;
      root.remove();
      scanning = false;
      resolve(result);
    };

    const onKeydown = (event) => {
      if (event.key === 'Escape') finish({ cancelled: true });
    };
    const onHashChange = () => finish({ cancelled: true });

    document.addEventListener('keydown', onKeydown);
    window.addEventListener('hashchange', onHashChange);
    closeButtons.forEach((button) => button.addEventListener('click', () => finish({ cancelled: true })));

    document.body.appendChild(root);
    if (appEl) appEl.inert = true; // fokus keyboard/pembaca layar tetap di pemindai
    closeButtons[closeButtons.length - 1].focus();

    (async () => {
      let mediaStream;
      try {
        mediaStream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } },
          audio: false
        });
      } catch (err) {
        finish({ error: cameraErrorMessage(err) });
        return;
      }
      if (finished) {
        stopStream(mediaStream);
        return;
      }
      stream = mediaStream;
      video.srcObject = stream;
      try {
        await video.play();
      } catch (err) { /* autoplay tetap berjalan lewat atribut */ }

      let detector;
      try {
        detector = await createBarcodeDetector();
      } catch (err) {
        finish({ error: 'Pemindai barcode gagal dimuat. Ketik barcode secara manual.' });
        return;
      }
      if (finished) return;

      status.textContent = 'Arahkan kamera ke barcode';

      const tick = async () => {
        if (finished) return;
        try {
          if (video.readyState >= 2) {
            const raw = await detector.detect(video);
            const code = raw ? String(raw).trim() : '';
            if (code) {
              if (navigator.vibrate) navigator.vibrate(60);
              finish({ code });
              return;
            }
          }
        } catch (err) { /* frame gagal dibaca — coba lagi di frame berikutnya */ }
        timer = setTimeout(tick, FRAME_INTERVAL_MS);
      };
      tick();
    })();
  });
}
