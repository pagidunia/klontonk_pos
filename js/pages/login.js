import { Auth } from '../auth.js';
import { UI } from '../ui.js';

export function renderLogin() {
  return `
    <div class="login-container">
      <div class="login-card">
        <div class="login-header">
          <div class="login-logo">K</div>
          <h1 class="login-title">Klontonk POS</h1>
          <p class="login-subtitle">Sistem Point of Sales Modern</p>
        </div>

        <form class="login-form" id="loginForm">
          <div class="form-group">
            <label for="username" class="form-label">Username</label>
            <input
              type="text"
              id="username"
              name="username"
              class="form-input"
              placeholder="Masukkan username"
              autocomplete="username"
              required
            />
          </div>

          <div class="form-group">
            <label for="password" class="form-label">Password</label>
            <input
              type="password"
              id="password"
              name="password"
              class="form-input"
              placeholder="Masukkan password"
              autocomplete="current-password"
              required
            />
          </div>

          <button type="submit" class="btn btn-primary btn-large">
            <span class="btn-text">Masuk</span>
          </button>

          <div class="login-error" id="loginError"></div>
        </form>

        <div class="login-divider">
          <span>Akun Demo</span>
        </div>

        <div class="demo-users">
          <div class="demo-user">
            <div class="demo-label">Pusat</div>
            <code class="demo-cred">admin</code>
            <code class="demo-cred">admin123</code>
          </div>
          <div class="demo-user">
            <div class="demo-label">Warung Merah</div>
            <code class="demo-cred">kasir_merah</code>
            <code class="demo-cred">kasir123</code>
          </div>
          <div class="demo-user">
            <div class="demo-label">Warung Putih</div>
            <code class="demo-cred">kasir_putih</code>
            <code class="demo-cred">kasir123</code>
          </div>
        </div>

        <p class="login-note">
          💡 User demo siap pakai untuk testing
        </p>
      </div>
    </div>
  `;
}

export function initLoginPage() {
  const form = document.getElementById('loginForm');
  const errorEl = document.getElementById('loginError');
  const usernameInput = document.getElementById('username');
  const passwordInput = document.getElementById('password');

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    errorEl.textContent = '';

    const username = usernameInput.value.trim();
    const password = passwordInput.value;

    if (!username || !password) {
      errorEl.textContent = 'Username dan password harus diisi';
      return;
    }

    const result = Auth.login(username, password);

    if (result.success) {
      UI.toast(`Selamat datang, ${result.user.name}!`, { type: 'success' });
      setTimeout(() => {
        window.location.reload();
      }, 300);
    } else {
      errorEl.textContent = result.error;
      passwordInput.value = '';
      usernameInput.focus();
    }
  });

  setTimeout(() => usernameInput.focus(), 100);
}
