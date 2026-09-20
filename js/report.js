// ============ LOGIKA LAPORAN PENJUALAN / STOK KELUAR ============
// Fungsi murni (tanpa DOM / penyimpanan) agar mudah diuji. Semua tanggal memakai waktu lokal;
// minggu dimulai hari Senin. Rentang selalu setengah-terbuka: [start, end).

export const PERIODS = [
  { id: 'harian', label: 'Harian' },
  { id: 'mingguan', label: 'Mingguan' },
  { id: 'bulanan', label: 'Bulanan' }
];

export const DAY_SHORT = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

export const startOfDay = (date) => new Date(date.getFullYear(), date.getMonth(), date.getDate());
const addDays = (date, n) => new Date(date.getFullYear(), date.getMonth(), date.getDate() + n);
const mondayIndex = (date) => (date.getDay() + 6) % 7; // Senin = 0 ... Minggu = 6

export function periodRange(kind, anchor) {
  const day = startOfDay(anchor);
  if (kind === 'harian') return { start: day, end: addDays(day, 1) };
  if (kind === 'mingguan') {
    const start = addDays(day, -mondayIndex(day));
    return { start, end: addDays(start, 7) };
  }
  if (kind === 'bulanan') {
    return {
      start: new Date(day.getFullYear(), day.getMonth(), 1),
      end: new Date(day.getFullYear(), day.getMonth() + 1, 1)
    };
  }
  throw new Error(`Periode tidak dikenal: ${kind}`);
}

// Geser jangkar ke periode sebelumnya (delta -1) atau berikutnya (+1).
export function shiftAnchor(kind, anchor, delta) {
  const day = startOfDay(anchor);
  if (kind === 'harian') return addDays(day, delta);
  if (kind === 'mingguan') return addDays(day, 7 * delta);
  return new Date(day.getFullYear(), day.getMonth() + delta, 1);
}

export const containsDate = (range, date) => date >= range.start && date < range.end;

const fmt = (date, options) => date.toLocaleDateString('id-ID', options);

export function periodLabel(kind, range) {
  if (kind === 'harian') return fmt(range.start, { weekday: 'long', day: 'numeric', month: 'short', year: 'numeric' });
  if (kind === 'bulanan') return fmt(range.start, { month: 'long', year: 'numeric' });

  const first = range.start;
  const last = addDays(range.end, -1);
  if (first.getFullYear() !== last.getFullYear()) {
    return `${fmt(first, { day: 'numeric', month: 'short', year: 'numeric' })} – ${fmt(last, { day: 'numeric', month: 'short', year: 'numeric' })}`;
  }
  if (first.getMonth() !== last.getMonth()) {
    return `${first.getDate()} ${fmt(first, { month: 'short' })} – ${last.getDate()} ${fmt(last, { month: 'short' })} ${last.getFullYear()}`;
  }
  return `${first.getDate()}–${last.getDate()} ${fmt(last, { month: 'short', year: 'numeric' })}`;
}

export function salesInRange(sales, range) {
  return sales.filter((sale) => containsDate(range, new Date(sale.at)));
}

function emptyBuckets(kind, range) {
  if (kind === 'harian') {
    return Array.from({ length: 24 }, (_, hour) => ({ key: hour, label: String(hour), qty: 0, revenue: 0, trx: 0 }));
  }
  if (kind === 'mingguan') {
    return DAY_SHORT.map((label, index) => ({
      key: index, label, sub: String(addDays(range.start, index).getDate()), qty: 0, revenue: 0, trx: 0
    }));
  }
  const days = new Date(range.start.getFullYear(), range.start.getMonth() + 1, 0).getDate();
  return Array.from({ length: days }, (_, index) => ({ key: index, label: String(index + 1), qty: 0, revenue: 0, trx: 0 }));
}

function bucketIndex(kind, date) {
  if (kind === 'harian') return date.getHours();
  if (kind === 'mingguan') return mondayIndex(date);
  return date.getDate() - 1;
}

// Rangkuman penjualan dalam satu periode.
//  items: barang yang keluar (jumlah & omzet), urut jumlah terbanyak
//  buckets: batang grafik (per jam / per hari)
export function aggregate(kind, range, sales) {
  const inRange = salesInRange(sales, range).sort((a, b) => new Date(b.at) - new Date(a.at));
  const buckets = emptyBuckets(kind, range);
  const items = new Map();
  let itemCount = 0;
  let revenue = 0;

  for (const sale of inRange) {
    const bucket = buckets[bucketIndex(kind, new Date(sale.at))];
    let saleQty = 0;

    for (const line of sale.lines) {
      const entry = items.get(line.id) || { id: line.id, name: line.name, unit: line.unit, qty: 0, revenue: 0 };
      entry.qty += line.qty;
      entry.revenue += line.qty * line.price;
      entry.name = line.name;
      entry.unit = line.unit;
      items.set(line.id, entry);
      saleQty += line.qty;
    }

    bucket.trx += 1;
    bucket.qty += saleQty;
    bucket.revenue += sale.total;
    itemCount += saleQty;
    revenue += sale.total;
  }

  const ranked = [...items.values()].sort((a, b) => b.qty - a.qty || a.name.localeCompare(b.name, 'id'));
  return {
    sales: inRange,
    trxCount: inRange.length,
    itemCount,
    kindCount: ranked.length,
    revenue,
    items: ranked,
    buckets,
    peakQty: buckets.reduce((max, bucket) => Math.max(max, bucket.qty), 0)
  };
}
