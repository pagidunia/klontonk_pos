import { ThemeManager } from './theme.js';
import { TenantStore } from './tenant.js';
import { UI } from './ui.js';
import { Router } from './router.js';
import { renderHome } from './pages/home.js';
import { Auth } from './auth.js';
import { renderLogin, initLoginPage } from './pages/login.js';

// === Initialize core systems ===
ThemeManager.init();
TenantStore.init();

// === Check Authentication — tampilkan login jika belum login ===
if (!Auth.isAuthenticated()) {
  document.getElementById('app').style.display = 'none';
  document.body.insertAdjacentHTML('beforeend', `<div id="loginRoot">${renderLogin()}</div>`);
  initLoginPage();
} else {
  initAuthenticatedApp();
}

function initAuthenticatedApp() {

// Update profile info dengan current user
const currentUser = Auth.getCurrentUser();
if (currentUser) {
  const profileNameEl = document.querySelector('.profile-name');
  const profileRoleEl = document.querySelector('.profile-role');
  const avatarEl = document.querySelector('.avatar');
  if (profileNameEl) profileNameEl.textContent = currentUser.name;
  if (profileRoleEl) profileRoleEl.textContent = currentUser.role === 'admin' ? 'Admin' : 'Kasir';
  if (avatarEl) avatarEl.textContent = currentUser.avatar;

  // Set tenant aktif sesuai user yang login
  TenantStore.setCurrent(currentUser.tenant);
}

// === Service Worker dinonaktifkan sementara (development) ===
// Cache-nya bikin perubahan file tidak langsung terlihat saat development.
// Unregister semua SW yang mungkin sudah ter-install dari sesi sebelumnya.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((regs) => {
    regs.forEach((reg) => reg.unregister());
  });
  caches?.keys().then((keys) => keys.forEach((k) => caches.delete(k)));
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

// === Logout Button ===
const logoutBtn = document.querySelector('.logout-btn');
if (logoutBtn) {
  logoutBtn.addEventListener('click', () => {
    Auth.logout();
    UI.toast('Anda telah logout', { type: 'success' });
    setTimeout(() => {
      window.location.reload();
    }, 300);
  });
}

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

// === Tenant Display (Read-only) ===
const tenantNameEl = document.getElementById('tenantName');
const drawerTenantEl = document.getElementById('drawerTenant');

function updateTenantUI(tenant) {
  tenantNameEl.textContent = tenant.name;
  drawerTenantEl.textContent = tenant.name;
}

TenantStore.subscribe(updateTenantUI);
updateTenantUI(TenantStore.getCurrent());

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

} // end initAuthenticatedApp