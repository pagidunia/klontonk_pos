/**
 * Multi-Tenancy Layer
 * Menyimpan konteks tenant aktif. Siap untuk di-hook ke API header.
 */
export const TenantStore = {
  _tenants: [
    { id: 'T001', name: 'Toko Pusat', code: 'TP' },
    { id: 'T002', name: 'Cabang Sudirman', code: 'SD' },
    { id: 'T003', name: 'Cabang Bekasi', code: 'BK' },
    { id: 'T004', name: 'Gudang Utama', code: 'GU' }
  ],
  
  _current: null,
  _listeners: new Set(),
  
  init() {
    const saved = localStorage.getItem('klontonk:tenant');
    this._current = saved 
      ? this._tenants.find(t => t.id === saved) 
      : this._tenants[0];
  },
  
  getAll() { return [...this._tenants]; },
  
  getCurrent() { return this._current; },
  
  setCurrent(tenantId) {
    const tenant = this._tenants.find(t => t.id === tenantId);
    if (!tenant || tenant.id === this._current.id) return;
    this._current = tenant;
    localStorage.setItem('klontonk:tenant', tenantId);
    this._listeners.forEach(fn => fn(tenant));
  },
  
  subscribe(fn) {
    this._listeners.add(fn);
    return () => this._listeners.delete(fn);
  },
  
  /**
   * Siap untuk API integration.
   * Contoh: fetch('/api/stock', { headers: { 'X-Tenant-Id': this.getApiContext().tenantId }})
   */
  getApiContext() {
    return {
      tenantId: this._current.id,
      tenantCode: this._current.code,
      tenantName: this._current.name
    };
  }
};