// Status koneksi ke Supabase, diperiksa langsung dari browser.
// Yang dicek: apakah project Supabase terjangkau dari perangkat ini (bukan apakah login/kunci valid).
import { SUPABASE_URL } from './config.js';

const HEALTH_URL = SUPABASE_URL + '/auth/v1/health';
const REQUEST_TIMEOUT_MS = 12000;

const DESCRIPTIONS = {
  connected: { tone: 'ok', label: 'Tersambung' },
  unreachable: { tone: 'bad', label: 'Supabase tidak terjangkau' }
};

// Kembalikan { state, latencyMs? }; tidak pernah melempar error.
// mode 'no-cors': cukup tahu server menjawab (apa pun status HTTP-nya), isi jawaban tidak dibaca.
export async function checkDbStatus() {
  const started = Date.now();
  try {
    await fetch(HEALTH_URL, { mode: 'no-cors', cache: 'no-store', signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) });
    return { state: 'connected', latencyMs: Date.now() - started };
  } catch (e) {
    return { state: 'unreachable' };
  }
}

// Teks dan warna untuk ditampilkan; latency ikut bila tersambung.
export function describeDb(status) {
  const known = DESCRIPTIONS[status && status.state] || DESCRIPTIONS.unreachable;
  const speed = status && status.state === 'connected' && Number.isFinite(status.latencyMs) ? ` · ${status.latencyMs} ms` : '';
  return { tone: known.tone, text: known.label + speed };
}
