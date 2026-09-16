import { ThemeManager } from './theme.js';
import { TenantStore } from './tenant.js';
import { UI } from './ui.js';
import { Router } from './router.js';
import { renderHome } from './pages/home.js';

// === Initialize core systems ===
ThemeManager.init();
TenantStore.init();

// === Register Service Worker ===
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {
      // Silent fail — SW optional
    });
  });
}

// === Drawer Toggle ===
const burgerBtn = document.getElementById('burgerBtn');
const drawer = document.getElementById('drawer');
const drawerOverlay = document.getElementById('drawerOverlay');

function openDrawer() {
  drawer.classList.add('open');
  drawerOverlay.classList.add('visible');
  burgerBtn.setAttribute('aria-expanded', 'true');
  drawer.setAttribute('aria-hidden', 'false');
}

function closeDrawer() {
  drawer.classList.remove('open');
  drawerOverlay.classList.remove('visible');
  burgerBtn.setAttribute('aria-expanded', 'false');
  drawer.setAttribute('aria-hidden', 'true');
}

burgerBtn.addEventListener('click', () => {
  const isOpen = drawer.classList.contains('open');
  isOpen ? closeDrawer() : openDrawer();
});

drawerOverlay.addEventListener('click', closeDrawer);

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && drawer.classList.contains('open')) closeDrawer();
});

// === Nav Group Toggle (Stok submenu) ===
document.querySelectorAll('.nav-toggle').forEach(btn => {
  btn.addEventListener('click', () => {
    const group = btn.dataset.group;
    const sublist = document.querySelector(`[data-sublist="${group}"]`);
    const expanded = btn.getAttribute('aria-expanded') === 'true';
    btn.setAttribute('aria-expanded', !expanded);
    sublist.classList.toggle('open');
  });
});

// === Close drawer on nav click (mobile) ===
document.querySelectorAll('.nav-item, .nav-sublist a').forEach(link => {
  link.addEventListener('click', () => {
    if (window.innerWidth < 1024) closeDrawer();
  });
});

// === Theme Toggle ===
document.getElementById('themeToggle').addEventListener('click', () => {
  const next = ThemeManager.toggle();
  UI.toast(`Mode ${next === 'dark' ? 'gelap' : 'terang'} aktif`, { type: 'success' });
});

// === Tenant Switcher ===
const tenantChip = document.getElementById('tenantChip');
const tenantNameEl = document.getElementById('tenantName');
const drawerTenantEl = document.getElementById('drawerTenant');

function updateTenantUI(tenant) {
  tenantNameEl.textContent = tenant.name;
  drawerTenantEl.textContent = tenant.name;
}

TenantStore.subscribe(updateTenantUI);

tenantChip.addEventListener('click', async () => {
  const tenants = TenantStore.getAll();
  const current = TenantStore.getCurrent();
  
  const root = document.getElementById('modalRoot');
  root.innerHTML = '';
  
  const backdrop = document.createElement('div');
  backdrop.className = 'modal-backdrop';
  
  const dialog = document.createElement('div');
  dialog.className = 'modal-dialog';
  dialog.setAttribute('role', 'dialog');
  
  dialog.innerHTML = `
    <h2 class="modal-title">Pilih Tenant</h2>
    <div class="modal-body">Aktifkan tenant untuk konteks data saat ini.</div>
    <div class="tenant-list">
      ${tenants.map(t => `
        <button class="tenant-option ${t.id === current.id ? 'selected' : ''}" data-tenant="${t.id}">
          <div class="tenant-option-logo">${t.code}</div>
          <div class="tenant-option-info">
            <div class="tenant-option-name">${t.name}</div>
            <div class="tenant-option-id">${t.id}</div>
          </div>
          <svg class="tenant-option-check" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
        </button>
      `).join('')}
    </div>
    <div class="modal-actions">
      <button class="btn btn-secondary" data-action="close">Tutup</button>
    </div>
  `;
  
  root.appendChild(backdrop);
  root.appendChild(dialog);
  requestAnimationFrame(() => {
    root.classList.add('visible');
    root.setAttribute('aria-hidden', 'false');
  });
  
  const close = () => {
    root.classList.remove('visible');
    root.setAttribute('aria-hidden', 'true');
    setTimeout(() => { root.innerHTML = ''; }, 250);
  };
  
  dialog.querySelectorAll('.tenant-option').forEach(opt => {
    opt.addEventListener('click', () => {
      TenantStore.setCurrent(opt.dataset.tenant);
      UI.toast(`Tenant diubah ke ${TenantStore.getCurrent().name}`, { type: 'success' });
      close();
    });
  });
  
  dialog.querySelector('[data-action="close"]').onclick = close;
  backdrop.onclick = close;
});

// === Quick Card Navigation ===
document.addEventListener('click', (e) => {
  const card = e.target.closest('[data-navigate]');
  if (card) {
    window.location.hash = card.dataset.navigate.slice(1);
  }
});

// === Router Setup ===
const router = new Router();

router
  .add('/beranda', renderHome)
  .add('/kasir', () => placeholderPage('Menu Kasir', 'Halaman kasir akan menampilkan layar transaksi.'))
  .add('/stok/awal', () => placeholderPage('Stok Awal', 'Input dan lihat stok awal periode.'))
  .add('/stok/keluar-laku', () => placeholderPage('Stok Keluar — Laku', 'Laporan stok keluar akibat penjualan.'))
  .add('/stok/keluar-mutasi', () => placeholderPage('Stok Keluar — Mutasi', 'Laporan mutasi antar cabang/gudang.'))
  .add('/stok/retur', () => placeholderPage('Stok Retur', 'Proses dan laporan retur barang.'))
  .add('/stok/total', () => placeholderPage('Stok Total', 'Rekap stok keseluruhan semua SKU.'))
  .add('/harga', () => placeholderPage('Update Harga', 'Ubah harga produk secara massal atau per item.'))
  .add('/laporan-kasir', () => placeholderPage('Laporan Kasir', 'Preview dan cetak laporan kasir harian.'))
  .add('/gudang', () => placeholderPage('Gudang', 'Manajemen inventori gudang pusat.'))
  .setNotFound(() => placeholderPage('404', 'Halaman yang Anda tuju tidak ditemukan.'))
  .start();

function placeholderPage(title, description) {
  return `
    <div class="page-header">
      <p class="greeting">Dalam Pengembangan</p>
      <h1 class="page-title">${title}</h1>
      <p class="page-subtitle">${description}</p>
    </div>
    <div class="activity-card" style="text-align:center; padding: 40px 20px;">
      <div style="width:64px;height:64px;border-radius:var(--radius-lg);background:var(--color-primary-soft);color:var(--color-primary);display:flex;align-items:center;justify-content:center;margin:0 auto 16px;">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"></circle>
          <polyline points="12 6 12 12 16 14"></polyline>
        </svg>
      </div>
      <h3 style="font-size:16px;font-weight:700;margin-bottom:8px;">Segera Hadir</h3>
      <p style="font-size:13px;color:var(--text-secondary);max-width:320px;margin:0 auto;">
        UI untuk halaman ini sedang dalam tahap desain. Fokus saat ini adalah fondasi navigasi dan tema.
      </p>
    </div>
  `;
}

// === Welcome Toast ===
setTimeout(() => {
  UI.toast(`Selamat datang di Klontonk POS · ${TenantStore.getCurrent().name}`, { type: 'success' });
}, 500);