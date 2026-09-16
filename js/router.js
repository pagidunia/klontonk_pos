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
    
    // Update active nav
    document.querySelectorAll('.nav-item, .nav-sublist a').forEach(el => {
      el.classList.toggle('active', el.getAttribute('href') === `#${hash}`);
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