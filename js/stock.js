import { TenantStore } from './tenant.js';

// Stok & harga per tenant. Sumber datanya blok STOCK_DATA di bawah (tanpa Local Storage).
// Setiap tambah/edit/hapus/ubah harga, data dikirim ke server.mjs (PUT api/stock) yang
// menulis ulang blok itu di file ini. Jangan hapus penanda BEGIN/END STOCK_DATA.
// Validasi dilakukan di sini (dan diulang di server.mjs); halaman hanya lapisan tampilan.
const SAVE_URL = 'api/stock';
const LEGACY_KEY_PREFIX = 'klontonk:stok-awal:';
const MAX_QTY = 1000000;
export const MAX_PRICE = 100000000;
const NAME_PATTERN = /^[\p{L}\p{N} .,'()&/+-]{2,60}$/u;
export const BARCODE_PATTERN = /^[A-Za-z0-9._-]{4,40}$/;

const sameBarcode = (a, b) => String(a || '').toLowerCase() === String(b || '').toLowerCase();

export const UNITS = ['pcs', 'kg', 'liter', 'pak', 'bungkus', 'dus', 'karung', 'renceng'];

// BEGIN STOCK_DATA
const STOCK_DATA = {
  "T001": [
    {
      "id": "stk_seed_0",
      "name": "Beras Lahap",
      "qty": 100,
      "unit": "kg",
      "price": 65000
    },
    {
      "id": "stk_seed_1",
      "name": "Gulaku",
      "qty": 60,
      "unit": "pak",
      "price": 30000
    },
    {
      "id": "stk_seed_2",
      "name": "Minyak Goreng Sania",
      "qty": 48,
      "unit": "pcs",
      "price": 40000
    },
    {
      "id": "stk_seed_3",
      "name": "Tepung Segitiga",
      "qty": 35,
      "unit": "pak",
      "price": 20000
    },
    {
      "id": "stk_seed_4",
      "name": "Garam Kapal",
      "qty": 50,
      "unit": "bungkus",
      "price": 8000
    },
    {
      "id": "stk_seed_5",
      "name": "Mie Sedap Goreng",
      "qty": 12,
      "unit": "dus",
      "price": 30000
    },
    {
      "id": "stk_seed_6",
      "name": "Telur Ayam",
      "qty": 25,
      "unit": "kg",
      "price": 30000
    },
    {
      "id": "stk_seed_7",
      "name": "Kopi Kapal Api",
      "qty": 20,
      "unit": "renceng",
      "price": 15000
    },
    {
      "id": "stk_seed_8",
      "name": "Teh Poci",
      "qty": 15,
      "unit": "pak",
      "price": 12000
    },
    {
      "id": "stk_seed_9",
      "name": "Cutter Kenko",
      "qty": 1,
      "unit": "pcs",
      "barcode": "8998838060018",
      "price": 15000
    }
  ],
  "T002": [
    {
      "id": "stk_seed_0",
      "name": "Beras Lahap",
      "qty": 100,
      "unit": "kg",
      "price": 65000
    },
    {
      "id": "stk_seed_1",
      "name": "Gulaku",
      "qty": 60,
      "unit": "pak",
      "price": 30000
    },
    {
      "id": "stk_seed_2",
      "name": "Minyak Goreng Sania",
      "qty": 48,
      "unit": "pcs",
      "price": 40000
    },
    {
      "id": "stk_seed_3",
      "name": "Tepung Segitiga",
      "qty": 35,
      "unit": "pak",
      "price": 20000
    },
    {
      "id": "stk_seed_4",
      "name": "Garam Kapal",
      "qty": 50,
      "unit": "bungkus",
      "price": 8000
    },
    {
      "id": "stk_seed_5",
      "name": "Mie Sedap Goreng",
      "qty": 12,
      "unit": "dus",
      "price": 30000
    },
    {
      "id": "stk_seed_6",
      "name": "Telur Ayam",
      "qty": 25,
      "unit": "kg",
      "price": 30000
    },
    {
      "id": "stk_seed_7",
      "name": "Kopi Kapal Api",
      "qty": 20,
      "unit": "renceng",
      "price": 15000
    },
    {
      "id": "stk_seed_8",
      "name": "Teh Poci",
      "qty": 15,
      "unit": "pak",
      "price": 12000
    },
    {
      "id": "stk_seed_9",
      "name": "Cutter Kenko",
      "qty": 1,
      "unit": "pcs",
      "barcode": "8998838060018"
    }
  ],
  "T003": [
    {
      "id": "stk_seed_0",
      "name": "Beras Lahap",
      "qty": 100,
      "unit": "kg",
      "price": 65000
    },
    {
      "id": "stk_seed_1",
      "name": "Gulaku",
      "qty": 60,
      "unit": "pak",
      "price": 30000
    },
    {
      "id": "stk_seed_2",
      "name": "Minyak Goreng Sania",
      "qty": 48,
      "unit": "pcs",
      "price": 40000
    },
    {
      "id": "stk_seed_3",
      "name": "Tepung Segitiga",
      "qty": 35,
      "unit": "pak",
      "price": 20000
    },
    {
      "id": "stk_seed_4",
      "name": "Garam Kapal",
      "qty": 50,
      "unit": "bungkus",
      "price": 8000
    },
    {
      "id": "stk_seed_5",
      "name": "Mie Sedap Goreng",
      "qty": 12,
      "unit": "dus",
      "price": 30000
    },
    {
      "id": "stk_seed_6",
      "name": "Telur Ayam",
      "qty": 25,
      "unit": "kg",
      "price": 30000
    },
    {
      "id": "stk_seed_7",
      "name": "Kopi Kapal Api",
      "qty": 20,
      "unit": "renceng",
      "price": 15000
    },
    {
      "id": "stk_seed_8",
      "name": "Teh Poci",
      "qty": 15,
      "unit": "pak",
      "price": 12000
    },
    {
      "id": "stk_seed_9",
      "name": "Cutter Kenko",
      "qty": 1,
      "unit": "pcs",
      "barcode": "8998838060018"
    }
  ]
};
// END STOCK_DATA

let data = structuredClone(STOCK_DATA);
let saveChain = Promise.resolve();
const saveErrorHandlers = new Set();

// Data stok versi lama tersimpan di Local Storage; sekarang tidak dipakai lagi.
try {
  Object.keys(localStorage)
    .filter((key) => key.startsWith(LEGACY_KEY_PREFIX))
    .forEach((key) => localStorage.removeItem(key));
} catch (e) { /* storage diblokir — tidak masalah */ }

const newId = () => 'stk_' + Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36);

function read() {
  return data[TenantStore.getCurrent().id] || [];
}

function commit(items) {
  data = { ...data, [TenantStore.getCurrent().id]: items };
  persist();
}

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
    throw new Error('Server penyimpanan belum aktif. Jalankan "node server.mjs", bukan http.server.');
  }
  throw new Error(`Server menolak data (kode ${response.status}).`);
}

// Simpan diserialkan; data terbaru dikirim tiap giliran sehingga simpan beruntun tidak saling menimpa.
function persist() {
  saveChain = saveChain
    .then(saveAll)
    .catch((err) => {
      const message = `${err.message} Perubahan belum tersimpan ke js/stock.js dan hilang saat refresh.`;
      saveErrorHandlers.forEach((handler) => handler(message));
    });
}

// Mengembalikan { ok: true, value } atau { ok: false, error }
function validate(input, items, ignoreId) {
  const name = String((input && input.name) ?? '').replace(/\s+/g, ' ').trim();
  const rawQty = String((input && input.qty) ?? '').trim();
  const unit = String((input && input.unit) ?? '');

  if (!name) return { ok: false, error: 'Nama barang wajib diisi.' };
  if (!NAME_PATTERN.test(name)) {
    return { ok: false, error: 'Nama barang 2–60 karakter (huruf, angka, spasi, dan tanda baca umum).' };
  }
  if (rawQty === '') return { ok: false, error: 'Jumlah stok wajib diisi.' };

  const qty = Number(rawQty);
  if (!Number.isInteger(qty) || qty < 0 || qty > MAX_QTY) {
    return { ok: false, error: 'Jumlah harus bilangan bulat 0 – 1.000.000.' };
  }
  if (!UNITS.includes(unit)) return { ok: false, error: 'Satuan tidak valid.' };

  const duplicate = items.some(i => i.id !== ignoreId && i.name.toLowerCase() === name.toLowerCase());
  if (duplicate) return { ok: false, error: 'Barang dengan nama itu sudah ada.' };

  // Barcode opsional; bila diisi harus unik per tenant.
  const barcode = String((input && input.barcode) ?? '').trim();
  if (barcode && !BARCODE_PATTERN.test(barcode)) {
    return { ok: false, error: 'Barcode 4–40 karakter (huruf, angka, titik, minus, underscore).' };
  }
  const barcodeOwner = barcode ? items.find(i => i.id !== ignoreId && i.barcode && sameBarcode(i.barcode, barcode)) : null;
  if (barcodeOwner) return { ok: false, error: `Barcode sudah dipakai oleh "${barcodeOwner.name}".` };

  return { ok: true, value: { name, qty, unit, barcode } };
}

export const StockStore = {
  // Dipanggil bila data gagal ditulis ke js/stock.js; mengembalikan fungsi untuk berhenti mendengarkan.
  onSaveError(handler) {
    saveErrorHandlers.add(handler);
    return () => saveErrorHandlers.delete(handler);
  },

  list() {
    return read().map(item => ({ ...item }));
  },

  findByBarcode(code) {
    const text = String(code || '').trim();
    if (!text) return null;
    const found = read().find(i => i.barcode && sameBarcode(i.barcode, text));
    return found ? { ...found } : null;
  },

  add(input) {
    const items = read();
    const checked = validate(input, items, null);
    if (!checked.ok) return { success: false, error: checked.error };

    const item = { id: newId(), ...checked.value };
    commit([...items, item]);
    return { success: true, item };
  },

  update(id, input) {
    const items = read();
    if (!items.some(i => i.id === id)) return { success: false, error: 'Barang tidak ditemukan.' };

    const checked = validate(input, items, id);
    if (!checked.ok) return { success: false, error: checked.error };

    const next = items.map(i => (i.id === id ? { ...i, ...checked.value } : i));
    commit(next);
    return { success: true, item: next.find(i => i.id === id) };
  },

  remove(id) {
    const items = read();
    if (!items.some(i => i.id === id)) return { success: false, error: 'Barang tidak ditemukan.' };
    commit(items.filter(i => i.id !== id));
    return { success: true };
  },

  // Harga jual per barang (rupiah, bilangan bulat).
  setPrice(id, rawPrice) {
    const items = read();
    if (!items.some(i => i.id === id)) return { success: false, error: 'Barang tidak ditemukan.' };

    const text = String(rawPrice ?? '').trim();
    if (text === '') return { success: false, error: 'Harga wajib diisi.' };

    const price = Number(text);
    if (!Number.isInteger(price) || price < 1 || price > MAX_PRICE) {
      return { success: false, error: 'Harga harus bilangan bulat Rp 1 – Rp 100.000.000.' };
    }

    const next = items.map(i => (i.id === id ? { ...i, price } : i));
    commit(next);
    return { success: true, item: next.find(i => i.id === id) };
  }
};
