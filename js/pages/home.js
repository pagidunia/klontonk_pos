import { TenantStore } from '../tenant.js';

export function renderHome() {
  const tenant = TenantStore.getCurrent();
  const now = new Date();
  const hour = now.getHours();
  const greeting = hour < 11 ? 'Selamat Pagi' : hour < 15 ? 'Selamat Siang' : hour < 18 ? 'Selamat Sore' : 'Selamat Malam';
  
  return `
    <div class="page-header">
      <p class="greeting">${greeting} · ${tenant.name}</p>
      <h1 class="page-title">Dashboard Klontonk</h1>
      <p class="page-subtitle">Ringkasan operasional hari ini, ${now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long' })}</p>
    </div>
    
    <section class="stats-grid" aria-label="Statistik hari ini">
      <div class="stat-card" style="--accent-color: #0060AF; --accent-bg: #E8F1FA;">
        <div class="stat-icon">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="1" x2="12" y2="23"></line>
            <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path>
          </svg>
        </div>
        <p class="stat-label">Omzet Hari Ini</p>
        <p class="stat-value">Rp 12,4 Jt</p>
        <span class="stat-trend up">↑ 8,2%</span>
      </div>
      
      <div class="stat-card" style="--accent-color: #16A34A; --accent-bg: rgba(22,163,74,0.1);">
        <div class="stat-icon">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path>
            <line x1="3" y1="6" x2="21" y2="6"></line>
          </svg>
        </div>
        <p class="stat-label">Transaksi</p>
        <p class="stat-value">148</p>
        <span class="stat-trend up">↑ 12%</span>
      </div>
      
      <div class="stat-card" style="--accent-color: #F59E0B; --accent-bg: rgba(245,158,11,0.1);">
        <div class="stat-icon">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
          </svg>
        </div>
        <p class="stat-label">Item Stok Rendah</p>
        <p class="stat-value">23</p>
        <span class="stat-trend down">↓ perlu restok</span>
      </div>
      
      <div class="stat-card" style="--accent-color: #0891B2; --accent-bg: rgba(8,145,178,0.1);">
        <div class="stat-icon">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
            <circle cx="9" cy="7" r="4"></circle>
            <path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"></path>
          </svg>
        </div>
        <p class="stat-label">Pelanggan Aktif</p>
        <p class="stat-value">89</p>
        <span class="stat-trend up">↑ 4%</span>
      </div>
    </section>
    
    <section aria-label="Aksi cepat">
      <h2 class="section-title">Aksi Cepat</h2>
      <div class="quick-grid">
        <button class="quick-card" data-navigate="#/kasir">
          <div class="quick-card-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="2" y="6" width="20" height="12" rx="2"></rect>
              <path d="M6 12h.01M10 12h.01M14 12h.01M18 12h.01"></path>
            </svg>
          </div>
          <div>
            <div class="quick-card-title">Transaksi</div>
            <div class="quick-card-desc">Transaksi penjualan baru</div>
          </div>
        </button>
        
        <button class="quick-card" data-navigate="#/stok/total">
          <div class="quick-card-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
            </svg>
          </div>
          <div>
            <div class="quick-card-title">Cek Stok</div>
            <div class="quick-card-desc">Lihat stok total</div>
          </div>
        </button>
        
        <button class="quick-card" data-navigate="#/harga">
          <div class="quick-card-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="12" y1="1" x2="12" y2="23"></line>
              <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path>
            </svg>
          </div>
          <div>
            <div class="quick-card-title">Update Harga</div>
            <div class="quick-card-desc">Sesuaikan harga produk</div>
          </div>
        </button>
        
        <button class="quick-card" data-navigate="#/laporan-kasir">
          <div class="quick-card-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
              <polyline points="14 2 14 8 20 8"></polyline>
            </svg>
          </div>
          <div>
            <div class="quick-card-title">Laporan Kasir</div>
            <div class="quick-card-desc">Cetak / preview laporan</div>
          </div>
        </button>
        
        <button class="quick-card" data-navigate="#/gudang">
          <div class="quick-card-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M3 21h18M3 10h18M5 6l7-3 7 3M4 10v11M20 10v11"></path>
            </svg>
          </div>
          <div>
            <div class="quick-card-title">Gudang</div>
            <div class="quick-card-desc">Kelola inventori pusat</div>
          </div>
        </button>
        
        <button class="quick-card" data-navigate="#/stok/retur">
          <div class="quick-card-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="1 4 1 10 7 10"></polyline>
              <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"></path>
            </svg>
          </div>
          <div>
            <div class="quick-card-title">Retur Barang</div>
            <div class="quick-card-desc">Proses retur cepat</div>
          </div>
        </button>
      </div>
    </section>
    
    <section aria-label="Aktivitas terbaru">
      <h2 class="section-title">Aktivitas Terbaru</h2>
      <div class="activity-card">
        <div class="activity-list">
          <div class="activity-item">
            <div class="activity-dot"></div>
            <div class="activity-content">
              <div class="activity-title">Transaksi #TRX-20260916-00148 berhasil</div>
              <div class="activity-meta">2 menit lalu · Rp 245.000</div>
            </div>
          </div>
          <div class="activity-item">
            <div class="activity-dot" style="background: var(--color-warning); box-shadow: 0 0 0 3px rgba(245,158,11,0.15);"></div>
            <div class="activity-content">
              <div class="activity-title">Stok "Minyak Goreng 2L" tersisa 5 unit</div>
              <div class="activity-meta">15 menit lalu · perlu restok</div>
            </div>
          </div>
          <div class="activity-item">
            <div class="activity-dot" style="background: var(--color-success); box-shadow: 0 0 0 3px rgba(22,163,74,0.15);"></div>
            <div class="activity-content">
              <div class="activity-title">Mutasi 50 item dari Gudang → Cabang Sudirman</div>
              <div class="activity-meta">1 jam lalu · oleh Admin</div>
            </div>
          </div>
          <div class="activity-item">
            <div class="activity-dot" style="background: var(--color-info); box-shadow: 0 0 0 3px rgba(8,145,178,0.15);"></div>
            <div class="activity-content">
              <div class="activity-title">Update harga 12 produk kategori sembako</div>
              <div class="activity-meta">3 jam lalu · oleh Manager</div>
            </div>
          </div>
        </div>
      </div>
    </section>
  `;
}