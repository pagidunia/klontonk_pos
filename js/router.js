export class Router {
  constructor() {
    this.routes = new Map();
    this.mainEl = document.getElementById('appMain');
    this._notFound = () => '<div class="page-header"><h1 class="page-title">Halaman tidak ditemukan</h1></div>';
  }
  
  add(path, handler) {
    this.routes.set(path, handler);
    return this;
  }
  
  setNotFound(handler) {
    this._notFound = handler;
    return this;
  }
  
  start() {
    window.addEventListener('hashchange', () => this._resolve());
    this._resolve();
  }
  
  navigate(path) {
    window.location.hash = path;
  }
  
  _resolve() {
    const hash = window.location.hash.slice(1) || '/beranda';
    const handler = this.routes.get(hash) || this._notFound;
    
    // Update active tab di Bottom Navigation (prefix match)
    const tabFor = (h) => {
      if (h === '/' || h === '/beranda') return 'beranda';
      if (h.startsWith('/stok')) return 'stok';
      if (h.startsWith('/kasir')) return 'transaksi';
      if (h.startsWith('/laporan')) return 'laporan';
      return null;
    };
    const activeTab = tabFor(hash);
    document.querySelectorAll('.bottom-tab').forEach(el => {
      el.classList.toggle('active', el.dataset.tab === activeTab);
    });
    
    // Render with subtle transition
    this.mainEl.style.opacity = '0';
    setTimeout(() => {
      this.mainEl.innerHTML = handler();
      this.mainEl.style.opacity = '1';
      this.mainEl.style.transition = 'opacity 200ms ease-out';
    }, 100);
  }
}