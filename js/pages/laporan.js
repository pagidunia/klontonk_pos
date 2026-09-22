import { StockStore } from '../stock.js';
import { TenantStore } from '../tenant.js';
import { Auth } from '../auth.js';
import { formatRupiah } from '../cart.js';
import { UI } from '../ui.js';

// ============ HALAMAN LAPORAN ============
// Wadah untuk berbagai laporan cetak/preview. Kontennya yang pertama: Laporan Stok Awal
// (daftar stok saat ini per tenant, siap cetak). Laporan lain (mis. penjualan) menyusul
// sebagai section baru di halaman ini.

const esc = (value) => UI._escape(String(value ?? ''));
const formatQty = (qty) => Number(qty).toLocaleString('id-ID');

const now = () => new Date().toLocaleString('id-ID', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' });

// Ringkasan: jenis barang, barang yang sudah berharga, dan estimasi nilai stok (hanya barang berharga).
function summarize(items) {
  return items.reduce((sum, item) => ({
    priced: sum.priced + (item.price != null ? 1 : 0),
    value: sum.value + (item.price != null ? item.qty * item.price : 0)
  }), { priced: 0, value: 0 });
}

function rowHtml(item) {
  const subtotal = item.price != null ? formatRupiah(item.qty * item.price) : '—';
  const harga = item.price != null ? formatRupiah(item.price) : '—';
  return `
    <tr>
      <td class="lap-cell-name">${esc(item.name)}</td>
      <td class="lap-cell-num">${esc(formatQty(item.qty))} ${esc(item.unit)}</td>
      <td class="lap-cell-num">${esc(harga)}</td>
      <td class="lap-cell-num">${esc(subtotal)}</td>
    </tr>`;
}

function tableHtml(items) {
  if (!items.length) {
    return '<p class="lap-empty">Belum ada barang di Stok Awal.</p>';
  }
  const sorted = [...items].sort((a, b) => a.name.localeCompare(b.name, 'id'));
  return `
    <div class="lap-table-wrap">
      <table class="lap-table">
        <thead>
          <tr><th>Nama Barang</th><th>Jumlah</th><th>Harga</th><th>Subtotal</th></tr>
        </thead>
        <tbody>${sorted.map(rowHtml).join('')}</tbody>
      </table>
    </div>`;
}

function stockReportHtml() {
  const items = StockStore.list();
  const tenant = TenantStore.getCurrent();
  const user = Auth.getCurrentUser();
  const { priced, value } = summarize(items);

  return `
    <section class="activity-card lap-card" aria-label="Laporan Stok Awal">
      <div class="lap-card-head">
        <div>
          <h2 class="section-title">Laporan Stok Awal</h2>
          <p class="lap-meta">${esc(tenant.name)} · Dicetak ${esc(now())}${user ? ` oleh ${esc(user.name)}` : ''}</p>
        </div>
        <button type="button" class="btn btn-secondary lap-print-btn" id="lapPrintBtn">Cetak</button>
      </div>

      <div class="rep-stats">
        <div class="rep-stat">
          <span class="rep-stat-label">Jenis Barang</span>
          <strong class="rep-stat-value">${items.length}</strong>
        </div>
        <div class="rep-stat">
          <span class="rep-stat-label">Sudah Berharga</span>
          <strong class="rep-stat-value">${priced}</strong>
          <span class="rep-stat-sub">dari ${items.length} barang</span>
        </div>
        <div class="rep-stat is-wide">
          <span class="rep-stat-label">Estimasi Nilai Stok</span>
          <strong class="rep-stat-value">${esc(formatRupiah(value))}</strong>
        </div>
      </div>

      ${tableHtml(items)}
    </section>`;
}

export function renderLaporanPage() {
  const tenant = TenantStore.getCurrent();
  return `
    <div class="page-header">
      <p class="greeting">Laporan · ${esc(tenant.name)}</p>
      <h1 class="page-title">Laporan</h1>
      <p class="page-subtitle">Preview dan cetak laporan stok serta penjualan.</p>
    </div>

    <div class="lap-page" id="lapPage">
      ${stockReportHtml()}
      <p class="lap-more-note">Laporan penjualan dan retur menyusul di sini.</p>
    </div>
  `;
}

export function initLaporanPage() {
  const page = document.getElementById('lapPage');
  if (!page) return;

  page.addEventListener('click', (event) => {
    if (event.target.closest('#lapPrintBtn')) window.print();
  });
}
