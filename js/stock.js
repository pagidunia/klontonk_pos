import { TenantStore } from './tenant.js';

// Penyimpanan stok awal per tenant (localStorage). Validasi dilakukan di sini,
// halaman hanya lapisan tampilan.
const KEY_PREFIX = 'klontonk:stok-awal:';
const MAX_QTY = 1000000;
export const MAX_PRICE = 100000000;
const NAME_PATTERN = /^[\p{L}\p{N} .,'()&/+-]{2,60}$/u;
export const BARCODE_PATTERN = /^[A-Za-z0-9._-]{4,40}$/;

const sameBarcode = (a, b) => String(a || '').toLowerCase() === String(b || '').toLowerCase();

export const UNITS = ['pcs', 'kg', 'liter', 'pak', 'bungkus', 'dus', 'karung', 'renceng'];

// Data awal (jumlah bersifat contoh/dummy).
const SEED_ITEMS = [
  { name: 'Beras Lahap', qty: 100, unit: 'kg' },
  { name: 'Gulaku', qty: 60, unit: 'pak' },
  { name: 'Minyak Goreng Sania', qty: 48, unit: 'pcs' },
  { name: 'Tepung Segitiga', qty: 35, unit: 'pak' },
  { name: 'Garam Kapal', qty: 50, unit: 'bungkus' },
  { name: 'Mie Sedap Goreng', qty: 12, unit: 'dus' },
  { name: 'Telur Ayam', qty: 25, unit: 'kg' },
  { name: 'Kopi Kapal Api', qty: 20, unit: 'renceng' },
  { name: 'Teh Poci', qty: 15, unit: 'pak' }
];

const storageKey = () => KEY_PREFIX + TenantStore.getCurrent().id;

const newId = () => 'stk_' + Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36);

function write(items) {
  try {
    localStorage.setItem(storageKey(), JSON.stringify(items));
    return true;
  } catch (e) {
    return false;
  }
}

function read() {
  let raw = null;
  try {
    raw = localStorage.getItem(storageKey());
  } catch (e) { /* storage diblokir */ }

  if (raw !== null) {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return parsed;
    } catch (e) { /* data korup — seed ulang */ }
  }

  const seeded = SEED_ITEMS.map((item, i) => ({ id: 'stk_seed_' + i, ...item }));
  write(seeded);
  return seeded;
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

const SAVE_FAILED = { success: false, error: 'Gagal menyimpan. Penyimpanan browser tidak tersedia.' };

export const StockStore = {
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
    if (!write([...items, item])) return SAVE_FAILED;
    return { success: true, item };
  },

  update(id, input) {
    const items = read();
    if (!items.some(i => i.id === id)) return { success: false, error: 'Barang tidak ditemukan.' };

    const checked = validate(input, items, id);
    if (!checked.ok) return { success: false, error: checked.error };

    const next = items.map(i => (i.id === id ? { ...i, ...checked.value } : i));
    if (!write(next)) return SAVE_FAILED;
    return { success: true, item: next.find(i => i.id === id) };
  },

  remove(id) {
    const items = read();
    if (!items.some(i => i.id === id)) return { success: false, error: 'Barang tidak ditemukan.' };
    if (!write(items.filter(i => i.id !== id))) return SAVE_FAILED;
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
    if (!write(next)) return SAVE_FAILED;
    return { success: true, item: next.find(i => i.id === id) };
  }
};
