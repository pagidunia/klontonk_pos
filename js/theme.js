export const ThemeManager = {
  _key: 'klontonk:theme',
  
  init() {
    const saved = localStorage.getItem(this._key);
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const theme = saved || (prefersDark ? 'dark' : 'light');
    this.apply(theme);
    
    window.matchMedia('(prefers-color-scheme: dark)')
      .addEventListener('change', (e) => {
        if (!localStorage.getItem(this._key)) {
          this.apply(e.matches ? 'dark' : 'light');
        }
      });
  },
  
  apply(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) {
      // Sama dengan warna header (--bg-surface) agar status bar menyatu.
      meta.setAttribute('content', theme === 'dark' ? '#121E33' : '#FFFFFF');
    }
  },
  
  toggle() {
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    this.apply(next);
    localStorage.setItem(this._key, next);
    return next;
  }
};