import { TenantStore } from './tenant.js';
import { trxNumber } from './cart.js';

// Riwayat penjualan per tenant. Sumber datanya blok SALES_DATA di bawah (tanpa Local Storage).
// Setiap penjualan baru dikirim ke server.mjs (PUT api/sales) yang menulis ulang blok itu di file ini.
// Jangan hapus penanda BEGIN/END SALES_DATA. Validasi diulang di server.mjs.
//
// Bentuk satu penjualan:
//   { no, at (ISO 8601), cashier, method: 'tunai' | 'nontunai', total, paid,
//     lines: [{ id, name, unit, qty, price }] }
const SAVE_URL = 'api/sales';
const MAX_SALES_PER_TENANT = 20000;

// BEGIN SALES_DATA
const SALES_DATA = {
  "T001": [
    {
      "no": "TRX-20260920-164748",
      "at": "2026-09-20T09:47:48.944Z",
      "cashier": "Admin Pusat",
      "method": "tunai",
      "total": 325000,
      "paid": 325000,
      "lines": [
        {
          "id": "stk_seed_0",
          "name": "Beras Lahap",
          "unit": "kg",
          "qty": 5,
          "price": 65000
        }
      ]
    }
  ]
};
// END SALES_DATA

let data = structuredClone(SALES_DATA);
let saveChain = Promise.resolve();
const saveErrorHandlers = new Set();

const currentSales = () => data[TenantStore.getCurrent().id] || [];

async function saveAll() {
  let response;
  try {
    response = await fetch(SAVE_URL, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
  } catch (e) {
    throw new Error('Server penyimpanan tidak terjangkau (offline?).');
  }
  if (response.ok) return;
  if (response.status === 404 || response.status === 405) {
    throw new Error('Server penyimpanan belum aktif atau belum diperbarui. Jalankan ulang "node server.mjs".');
  }
  throw new Error(`Server menolak data penjualan (kode ${response.status}).`);
}

// Simpan diserialkan; data terbaru dikirim tiap giliran sehingga simpan beruntun tidak saling menimpa.
function persist() {
  saveChain = saveChain
    .then(saveAll)
    .catch((err) => {
      const message = `${err.message} Riwayat penjualan belum tersimpan ke js/sales.js dan hilang saat refresh.`;
      saveErrorHandlers.forEach((handler) => handler(message));
    });
}

// Nomor unik: bila dua penjualan jatuh di detik yang sama, tambahkan akhiran -2, -3, ...
function uniqueNumber(date, existing) {
  const base = trxNumber(date);
  const taken = new Set(existing.map((sale) => sale.no));
  if (!taken.has(base)) return base;
  for (let n = 2; n < 1000; n++) {
    if (!taken.has(`${base}-${n}`)) return `${base}-${n}`;
  }
  return `${base}-${Date.now() % 1000}`;
}

export const SalesStore = {
  // Dipanggil bila data gagal ditulis ke js/sales.js; mengembalikan fungsi untuk berhenti mendengarkan.
  onSaveError(handler) {
    saveErrorHandlers.add(handler);
    return () => saveErrorHandlers.delete(handler);
  },

  // Penjualan tenant aktif (salinan), urutan tercatat.
  list() {
    return structuredClone(currentSales());
  },

  // Catat satu penjualan. input: { cashier, method, total, paid, lines }.
  record(input) {
    const existing = currentSales();
    if (!input || !Array.isArray(input.lines) || input.lines.length === 0) {
      return { success: false, error: 'Penjualan tanpa barang tidak dicatat.' };
    }
    if (existing.length >= MAX_SALES_PER_TENANT) {
      return { success: false, error: 'Riwayat penjualan penuh.' };
    }

    const now = new Date();
    // Nama kasir dibersihkan agar cocok dengan aturan validasi server.
    const cashier = String(input.cashier ?? '').replace(/[^\p{L}\p{N} .,'()&/+-]/gu, '').trim().slice(0, 60) || 'Kasir';
    const sale = {
      no: uniqueNumber(now, existing),
      at: now.toISOString(),
      cashier,
      method: input.method,
      total: input.total,
      paid: input.paid,
      lines: input.lines.map(({ id, name, unit, qty, price }) => ({ id, name, unit, qty, price }))
    };

    data = { ...data, [TenantStore.getCurrent().id]: [...existing, sale] };
    persist();
    return { success: true, sale: structuredClone(sale) };
  }
};
