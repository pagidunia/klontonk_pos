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
      meta.setAttribute('content', theme === 'dark' ? '#0A1628' : '#EBE4DB');
    }
  },
  
  toggle() {
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    this.apply(next);
    localStorage.setItem(this._key, next);
    return next;
  },
  
  current() {
    return document.documentElement.getAttribute('data-theme');
  }
};