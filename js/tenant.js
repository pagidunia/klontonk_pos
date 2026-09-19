/**
 * Multi-Tenancy Layer
 * Menyimpan konteks tenant aktif. Siap untuk di-hook ke API header.
 */
export const TenantStore = {
  _tenants: [
    { id: 'T001', name: 'Pusat', code: 'TP' },
    { id: 'T002', name: 'Warung Merah', code: 'WM' },
    { id: 'T003', name: 'Warung Putih', code: 'WP' }
  ],
  
  _current: null,
  _listeners: new Set(),
  
  init() {
    let saved = null;
    try {
      saved = localStorage.getItem('klontonk:tenant');
    } catch (e) { /* storage tidak tersedia */ }
    const found = saved ? this._tenants.find(t => t.id === saved) : null;
    // GUARD: nilai tersimpan yang tidak valid (atau storage kosong) fallback ke tenant pertama.
    // Tanpa ini, _current bisa undefined dan setCurrent() crash → seluruh app mati
    // (beranda kosong, navigasi tidak terpasang).
    this._current = found || this._tenants[0];
  },
  
  getAll() { return [...this._tenants]; },
  
  getCurrent() {
    // GUARD: jangan pernah mengembalikan null/undefined
    if (!this._current) this.init();
    return this._current;
  },
  
  setCurrent(tenantId) {
    const tenant = this._tenants.find(t => t.id === tenantId);
    if (!tenant) return; // ID tak dikenal → abaikan, biarkan tenant aktif
    if (this._current && tenant.id === this._current.id) return;
    this._current = tenant;
    try {
      localStorage.setItem('klontonk:tenant', tenantId);
    } catch (e) { /* abaikan */ }
    this._listeners.forEach(fn => fn(tenant));
  },
  
  subscribe(fn) {
    this._listeners.add(fn);
    return () => this._listeners.delete(fn);
  }
};