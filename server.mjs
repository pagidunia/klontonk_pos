#!/usr/bin/env node
// Server pengembangan Klontonk POS — pengganti `python3 -m http.server`.
//
// Selain menyajikan file statis, server ini menerima PUT /api/stock dan menulis ulang
// blok "BEGIN STOCK_DATA ... END STOCK_DATA" di js/stock.js. Itulah cara aplikasi
// mengubah data stok & harga tanpa Local Storage (browser tidak boleh menulis file).
//
// Jalankan:  node server.mjs            (http://localhost:8080)
// Opsi env:  PORT=8080  HOST=127.0.0.1  (pakai HOST=0.0.0.0 untuk uji dari HP di jaringan yang sama)
//
// Hanya untuk pengembangan. Nanti diganti backend/database sungguhan.

import http from 'node:http';
import { readFile, writeFile, rename, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const STOCK_FILE = path.join(ROOT, 'js', 'stock.js');
const PORT = Number(process.env.PORT) || 8080;
const HOST = process.env.HOST || '127.0.0.1';
const MAX_BODY_BYTES = 512 * 1024;
const MAX_ITEMS_PER_TENANT = 2000;

const BEGIN_MARK = '// BEGIN STOCK_DATA';
const END_MARK = '// END STOCK_DATA';

// Aturan validasi — harus sama dengan js/stock.js.
const UNITS = ['pcs', 'kg', 'liter', 'pak', 'bungkus', 'dus', 'karung', 'renceng'];
const MAX_QTY = 1000000;
const MAX_PRICE = 100000000;
const TENANT_ID_PATTERN = /^T\d{3}$/;
const ITEM_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;
const NAME_PATTERN = /^[\p{L}\p{N} .,'()&/+-]{2,60}$/u;
const BARCODE_PATTERN = /^[A-Za-z0-9._-]{4,40}$/;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8'
};

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// Mengembalikan salinan bersih (hanya field yang dikenal) atau melempar HttpError 422.
function sanitize(data) {
  const fail = (message) => { throw new HttpError(422, message); };
  if (!data || typeof data !== 'object' || Array.isArray(data)) fail('Data harus berupa objek per tenant.');

  const clean = {};
  for (const [tenantId, items] of Object.entries(data)) {
    if (!TENANT_ID_PATTERN.test(tenantId)) fail(`ID tenant tidak valid: ${tenantId}`);
    if (!Array.isArray(items) || items.length > MAX_ITEMS_PER_TENANT) fail(`Daftar barang ${tenantId} tidak valid.`);

    const seenIds = new Set();
    clean[tenantId] = items.map((item, index) => {
      const where = `${tenantId} #${index + 1}`;
      if (!item || typeof item !== 'object') fail(`Barang ${where} tidak valid.`);
      const { id, name, qty, unit, barcode, price } = item;

      if (typeof id !== 'string' || !ITEM_ID_PATTERN.test(id) || seenIds.has(id)) fail(`ID barang ${where} tidak valid atau ganda.`);
      seenIds.add(id);
      if (typeof name !== 'string' || !NAME_PATTERN.test(name)) fail(`Nama barang ${where} tidak valid.`);
      if (!Number.isInteger(qty) || qty < 0 || qty > MAX_QTY) fail(`Jumlah ${where} tidak valid.`);
      if (!UNITS.includes(unit)) fail(`Satuan ${where} tidak valid.`);

      const out = { id, name, qty, unit };
      if (barcode !== undefined && barcode !== '') {
        if (typeof barcode !== 'string' || !BARCODE_PATTERN.test(barcode)) fail(`Barcode ${where} tidak valid.`);
        out.barcode = barcode;
      }
      if (price !== undefined) {
        if (!Number.isInteger(price) || price < 1 || price > MAX_PRICE) fail(`Harga ${where} tidak valid.`);
        out.price = price;
      }
      return out;
    });
  }
  return clean;
}

// Penulisan diserialkan agar dua simpan beruntun tidak saling menimpa.
let writeQueue = Promise.resolve();

function writeStockData(data) {
  const job = writeQueue.then(async () => {
    const source = await readFile(STOCK_FILE, 'utf8');
    const begin = source.indexOf(BEGIN_MARK);
    const end = source.indexOf(END_MARK);
    if (begin === -1 || end === -1 || end < begin) {
      throw new HttpError(500, 'Penanda BEGIN/END STOCK_DATA tidak ditemukan di js/stock.js.');
    }
    const block = `${BEGIN_MARK}\nconst STOCK_DATA = ${JSON.stringify(data, null, 2)};\n`;
    const next = source.slice(0, begin) + block + source.slice(end);

    const temp = `${STOCK_FILE}.tmp`;
    await writeFile(temp, next, 'utf8');
    await rename(temp, STOCK_FILE); // atomik: file tidak pernah setengah tertulis
  });
  writeQueue = job.catch(() => {});
  return job;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new HttpError(413, 'Data terlalu besar.'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

async function handleStockSave(req, res) {
  const origin = req.headers.origin;
  if (origin) {
    let sameOrigin = false;
    try { sameOrigin = new URL(origin).host === req.headers.host; } catch (e) { /* origin rusak */ }
    if (!sameOrigin) throw new HttpError(403, 'Asal permintaan tidak diizinkan.');
  }
  if (!String(req.headers['content-type'] || '').includes('application/json')) {
    throw new HttpError(415, 'Content-Type harus application/json.');
  }

  let parsed;
  try {
    parsed = JSON.parse(await readBody(req));
  } catch (err) {
    if (err instanceof HttpError) throw err;
    throw new HttpError(400, 'JSON tidak valid.');
  }

  await writeStockData(sanitize(parsed));
  res.writeHead(204, { 'Cache-Control': 'no-store' });
  res.end();
}

async function serveStatic(req, res, pathname) {
  let relative;
  try {
    relative = decodeURIComponent(pathname);
  } catch (e) {
    throw new HttpError(400, 'URL tidak valid.');
  }

  const target = path.normalize(path.join(ROOT, relative));
  const inside = target === ROOT || target.startsWith(ROOT + path.sep);
  const segments = path.relative(ROOT, target).split(path.sep);
  // Tolak keluar dari folder proyek, file/folder tersembunyi (.git, .env), dan server itu sendiri.
  if (!inside || segments.some((s) => s.startsWith('.')) || segments[0] === 'server.mjs') {
    throw new HttpError(404, 'Tidak ditemukan.');
  }

  let file = target;
  try {
    if ((await stat(file)).isDirectory()) file = path.join(file, 'index.html');
    const body = await readFile(file);
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-cache'
    });
    res.end(req.method === 'HEAD' ? undefined : body);
  } catch (err) {
    throw new HttpError(404, 'Tidak ditemukan.');
  }
}

const server = http.createServer(async (req, res) => {
  try {
    const { pathname } = new URL(req.url, 'http://localhost');

    if (pathname === '/api/stock') {
      if (req.method !== 'PUT') throw new HttpError(405, 'Gunakan PUT.');
      await handleStockSave(req, res);
      return;
    }
    if (req.method !== 'GET' && req.method !== 'HEAD') throw new HttpError(405, 'Metode tidak diizinkan.');
    await serveStatic(req, res, pathname);
  } catch (err) {
    const status = err instanceof HttpError ? err.status : 500;
    if (!(err instanceof HttpError)) console.error(err);
    if (res.headersSent) return res.end();
    res.writeHead(status, { 'Content-Type': 'text/plain; charset=utf-8', ...(status === 405 && { Allow: 'GET, HEAD, PUT' }) });
    res.end(err instanceof HttpError ? err.message : 'Kesalahan server.');
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Klontonk POS berjalan di http://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT}`);
  console.log('Perubahan stok/harga dari aplikasi akan ditulis ke js/stock.js');
});
