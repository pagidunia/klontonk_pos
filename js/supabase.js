import { SUPABASE_URL, SUPABASE_KEY } from './config.js';

// Klien ringan untuk Supabase (Auth + PostgREST) memakai fetch biasa, tanpa pustaka.
// Semua fungsi mengembalikan { ok, status, data } atau { ok:false, status, code, message } dan tidak melempar error.
// status 0 = tidak ada jaringan / server tidak menjawab.

const SESSION_KEY = 'klontonk:sb-session'; // { access_token, refresh_token, expires_at (detik) }
const REFRESH_MARGIN_S = 60;
const REQUEST_TIMEOUT_MS = 20000;
const PAGE_SIZE = 1000; // batas baris per permintaan di Supabase

// ---------- Sesi (disimpan di localStorage; akses storage bisa diblokir) ----------

function readSession() {
  try {
    const stored = JSON.parse(localStorage.getItem(SESSION_KEY));
    return stored && stored.access_token && stored.refresh_token ? stored : null;
  } catch (e) {
    return null;
  }
}

function writeSession(value) {
  try {
    if (value) localStorage.setItem(SESSION_KEY, JSON.stringify(value));
    else localStorage.removeItem(SESSION_KEY);
  } catch (e) { /* abaikan */ }
}

let session = readSession();
let refreshing = null;

export const hasSession = () => session !== null;

export function clearSession() {
  session = null;
  writeSession(null);
}

const toSession = (data) => ({
  access_token: data.access_token,
  refresh_token: data.refresh_token,
  expires_at: data.expires_at || Math.floor(Date.now() / 1000) + data.expires_in
});

// ---------- Permintaan mentah ----------

function describeError(status, body) {
  const message = (body && (body.message || body.msg || body.error_description || body.error)) || `Permintaan gagal (kode ${status}).`;
  const code = body && (body.error_code || body.code);
  return { status, code: code ? String(code) : '', message };
}

async function raw(path, { method = 'GET', body, token, headers = {} } = {}) {
  let response;
  try {
    response = await fetch(SUPABASE_URL + path, {
      method,
      cache: 'no-store',
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      headers: {
        apikey: SUPABASE_KEY,
        ...(token && { Authorization: 'Bearer ' + token }),
        ...(body !== undefined && { 'Content-Type': 'application/json' }),
        ...headers
      },
      body: body === undefined ? undefined : JSON.stringify(body)
    });
  } catch (e) {
    return { ok: false, status: 0, code: 'network', message: 'Server tidak terjangkau. Periksa koneksi lalu coba lagi.' };
  }

  const text = await response.text().catch(() => '');
  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch (e) { data = text; }
  }
  if (response.ok) return { ok: true, status: response.status, data };
  return { ok: false, ...describeError(response.status, data) };
}

// ---------- Token: diperbarui otomatis sebelum kadaluarsa ----------

async function refreshSession() {
  if (!session) return false;
  const result = await raw('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: session.refresh_token } });
  if (result.ok) {
    session = toSession(result.data);
    writeSession(session);
    return true;
  }
  if (result.status === 0 || result.status >= 500) return false; // offline / gangguan: pertahankan sesi, coba lagi nanti
  clearSession(); // ditolak: sesi tidak berlaku lagi
  return false;
}

function refreshOnce() {
  if (!refreshing) refreshing = refreshSession().finally(() => { refreshing = null; });
  return refreshing;
}

async function freshToken() {
  if (!session) return null;
  if (session.expires_at - Date.now() / 1000 <= REFRESH_MARGIN_S) await refreshOnce();
  return session ? session.access_token : null;
}

// Permintaan atas nama pengguna yang login. `expired: true` bila sesi sudah tidak berlaku (harus login ulang).
export async function request(path, options = {}) {
  const token = await freshToken();
  let result = await raw(path, { ...options, token: token || undefined });
  if (result.status === 401 && session) {
    if (await refreshOnce()) result = await raw(path, { ...options, token: session.access_token });
  }
  return result.status === 401 ? { ...result, expired: true } : result;
}

export const rest = (path, options) => request('/rest/v1/' + path, options);
export const rpc = (name, args) => request('/rest/v1/rpc/' + name, { method: 'POST', body: args });

// Ambil semua baris (Supabase membatasi 1000 per permintaan): halaman demi halaman sampai habis.
export async function fetchAll(path) {
  const rows = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const page = await rest(path, { headers: { Range: `${from}-${from + PAGE_SIZE - 1}`, 'Range-Unit': 'items' } });
    if (!page.ok) return page;
    rows.push(...page.data);
    if (page.data.length < PAGE_SIZE) return { ok: true, status: 200, data: rows };
  }
}

// ---------- Auth ----------

export async function signIn(email, password) {
  const result = await raw('/auth/v1/token?grant_type=password', { method: 'POST', body: { email, password } });
  if (result.ok) {
    session = toSession(result.data);
    writeSession(session);
  }
  return result;
}

export async function signOut() {
  const token = session && session.access_token;
  clearSession();
  if (token) await raw('/auth/v1/logout?scope=local', { method: 'POST', token });
}

// Buat akun baru TANPA mengganti sesi yang sedang aktif (admin tidak ikut keluar).
export const signUpDetached = (email, password) => raw('/auth/v1/signup', { method: 'POST', body: { email, password } });
