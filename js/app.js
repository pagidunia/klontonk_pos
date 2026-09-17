import { ThemeManager } from './theme.js';
import { TenantStore } from './tenant.js';
import { UI } from './ui.js';
import { Router } from './router.js';
import { renderHome } from './pages/home.js';
import { Auth } from './auth.js';
import { renderLogin, initLoginPage } from './pages/login.js';
import { renderUsersPage, initUsersPage } from './pages/users.js';

// === Initialize core systems ===
ThemeManager.init();
TenantStore.init();

// === Check Authentication — tampilkan login jika belum login ===
// WAJIB menunggu inisialisasi auth selesai (verifikasi signature session
// bersifat async). Tanpa await ini, status login dibaca terlalu dini dan
// user yang sudah login selalu "dilempar kembali" ke halaman login.
await Auth.ready;

if (!Auth.isAuthenticated()) {
  document.getElementById('app').style.display = 'none';
  document.body.insertAdjacentHTML('beforeend', `<div id="loginRoot">${renderLogin()}</div>`);
  initLoginPage();
} else {
  initAuthenticatedApp();
}

function initAuthenticatedApp() {

try {

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
    UI.modal({
      title: 'Konfirmasi Keluar',
      message: 'Apakah Anda yakin ingin logout dari sistem?',
      icon: 'warning',
      confirmText: 'Ya, Keluar',
      cancelText: 'Batal',
      variant: 'danger'
    }).then((confirmed) => {
      if (confirmed) {
        Auth.logout();
        UI.toast('Anda telah logout', { type: 'success' });
        setTimeout(() => {
          window.location.reload();
        }, 300);
      }
    });
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
// HANYA link navigasi asli (<a>) yang menutup drawer.
// `.nav-toggle` adalah <button class="nav-item nav-toggle"> — jika ikut match,
// klik "Menu Stok" langsung menutup drawer sehingga sub-menu tampak "hilang".
document.querySelectorAll('a.nav-item, .nav-sublist a').forEach(link => {
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

// Cek admin secara defensif — kompatibel dengan semua versi Auth
// (fallback ke getCurrentUser() jika isAdmin() tidak tersedia)
function currentIsAdmin() {
  if (typeof Auth.isAdmin === 'function') return Auth.isAdmin();
  const u = Auth.getCurrentUser();
  return !!(u && u.role === 'admin');
}

// Tampilkan nav "Tambah User" HANYA untuk admin
(function setupAdminNav() {
  const navAdmin = document.querySelectorAll('.nav-admin-only');
  if (currentIsAdmin()) {
    navAdmin.forEach(el => { el.hidden = false; });
  } else {
    navAdmin.forEach(el => { el.remove(); }); // hapus dari DOM — bukan sekadar disembunyikan
  }
})();

// === Router Setup ===
const router = new Router();

// Guard: halaman admin ditolak untuk non-admin (cek ulang saat route diakses)
const adminGuard = (renderFn, initFn) => () => {
  if (!currentIsAdmin()) {
    return `
      <div class="page-header">
        <p class="greeting">Akses Ditolak</p>
        <h1 class="page-title">403</h1>
        <p class="page-subtitle">Halaman ini hanya dapat diakses oleh Admin.</p>
      </div>
      <div class="activity-card" style="text-align:center; padding: 40px 20px;">
        <div style="width:64px;height:64px;border-radius:var(--radius-lg);background:rgba(220,38,38,0.12);color:var(--color-danger);display:flex;align-items:center;justify-content:center;margin:0 auto 16px;">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
            <path d="M7 11V7a5 5 0 0 1 9.9-1"></path>
          </svg>
        </div>
        <h3 style="font-size:16px;font-weight:700;margin-bottom:8px;">Butuh Hak Akses Admin</h3>
        <p style="font-size:13px;color:var(--text-secondary);max-width:320px;margin:0 auto;">
          Jika Anda merasa ini keliru, hubungi admin pusat Anda.
        </p>
      </div>
    `;
  }
  // Render normal + init setelah DOM terpasang
  setTimeout(initFn, 150);
  return renderFn();
};

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
  .add('/users', adminGuard(renderUsersPage, initUsersPage))
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

// === Welcome Popup — sapaan login + info update & maintenance ===
// Perbarui data di bawah ini untuk rilis / jadwal maintenance berikutnya.
const WHATS_NEW = [
  { color: '#16A34A', title: 'Mode Terang Baru', desc: 'Palet krem hangat yang lebih nyaman dibaca sepanjang hari.' },
  { color: '#DC2626', title: 'Tombol Logout Lebih Kontras', desc: 'Sekarang tampil solid merah — lebih mudah ditemukan, lebih sulit salah tekan.' },
  { color: '#0060AF', title: 'Perbaikan Menu Stok', desc: 'Sub-menu Stok tidak lagi tertutup sendiri saat dibuka di layar kecil.' },
  { color: '#F59E0B', title: 'Navigasi Multi-Tenant', desc: 'Pindah antar cabang tetap ringan langsung dari header.' }
];

const MAINTENANCE_INFO = [
  { title: 'Maintenance Terjadwal', desc: 'Minggu, 02.00–03.00 WIB — sebagian fitur mungkin tidak tersedia sementara.' },
  { title: 'Roadmap Berikutnya', desc: 'Laporan kasir cetak, manajemen gudang, dan sinkronisasi stok antar cabang.' }
];

function showWelcomePopup() {
  const user = Auth.getCurrentUser();
  if (!user) return;

  // Muncul sekali per sesi login (key = waktu login)
  const seenKey = `klontonk:welcome:${user.loginTime || ''}`;
  try {
    if (sessionStorage.getItem(seenKey)) return;
  } catch (e) { /* storage tidak tersedia — popup tetap tampil */ }

  UI.welcome({
    name: user.name,
    tenantName: TenantStore.getCurrent().name,
    avatar: user.avatar || 'A',
    updates: WHATS_NEW,
    maintenance: MAINTENANCE_INFO
  }).then(() => {
    try { sessionStorage.setItem(seenKey, '1'); } catch (e) { /* abaikan */ }
  });
}

setTimeout(showWelcomePopup, 350);

} catch (err) {
  // Jangan biarkan satu error mematikan seluruh app (beranda kosong + nav mati).
  // Tampilkan pesan yang jelas agar mudah didiagnosis.
  console.error('[App] Gagal inisialisasi aplikasi:', err);
  const main = document.getElementById('appMain');
  if (main) {
    main.innerHTML = `
      <div class="page-header">
        <p class="greeting">Terjadi Kesalahan</p>
        <h1 class="page-title">Gagal Memuat</h1>
        <p class="page-subtitle">${String(err && err.message || err).replace(/[<>&"]/g, '')}</p>
      </div>
      <div class="activity-card" style="text-align:center; padding: 40px 20px;">
        <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;">
          Coba muat ulang halaman. Jika berlanjut, buka Console (F12) untuk detail.
        </p>
        <button class="btn btn-primary" id="errReloadBtn">Muat Ulang</button>
      </div>
    `;
    // CSP: JANGAN pakai inline onclick — pasang listener setelah render
    const reloadBtn = document.getElementById('errReloadBtn');
    if (reloadBtn) reloadBtn.addEventListener('click', () => window.location.reload());
  }
}

} // end initAuthenticatedApp