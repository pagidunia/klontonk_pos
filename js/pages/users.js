import { Auth } from '../auth.js';
import { TenantStore } from '../tenant.js';
import { UI } from '../ui.js';

// ============ HALAMAN TAMBAH USER (ADMIN ONLY) ============
// Semua output dinamis di-escape untuk mencegah XSS.
// Validasi ketat dilakukan di Auth.createUser() — halaman ini hanya lapisan UX.

const _escape = (str) => {
  const div = document.createElement('div');
  div.textContent = String(str ?? '');
  return div.innerHTML;
};

const _roleLabel = (role) => (role === 'admin' ? 'Admin' : 'Kasir');

export function renderUsersPage() {
  return `
    <div class="page-header">
      <p class="greeting">Manajemen Akun</p>
      <h1 class="page-title">Tambah User</h1>
      <p class="page-subtitle">Buat akun baru untuk admin atau kasir. Password disimpan sebagai salted hash — tidak pernah dalam bentuk teks asli.</p>
    </div>

    <div class="users-layout">
      <!-- ============ FORM TAMBAH USER ============ -->
      <section class="activity-card user-form-card" aria-label="Form tambah user">
        <h2 class="section-title" style="margin-bottom:16px;">Buat Akun Baru</h2>
        <form id="userForm" autocomplete="off" novalidate>
          <div class="form-group">
            <label for="newName" class="form-label">Nama Lengkap</label>
            <input type="text" id="newName" name="newName" class="form-input"
                   placeholder="cth: Kasir Warung Biru" maxlength="60" required />
          </div>

          <div class="form-group">
            <label for="newUsername" class="form-label">Username</label>
            <input type="text" id="newUsername" name="newUsername" class="form-input"
                   placeholder="cth: kasir_biru" maxlength="24" required
                   pattern="[a-z0-9_.]{3,24}" spellcheck="false" />
            <p class="field-hint">3–24 karakter: huruf kecil, angka, titik, underscore.</p>
          </div>

          <div class="form-group">
            <label for="newPassword" class="form-label">Password</label>
            <div class="password-wrap">
              <input type="password" id="newPassword" name="newPassword" class="form-input"
                     placeholder="Minimal 8 karakter, huruf + angka" maxlength="128" required
                     autocomplete="new-password" />
              <button type="button" class="password-toggle" id="pwToggle" aria-label="Tampilkan password">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                  <circle cx="12" cy="12" r="3"></circle>
                </svg>
              </button>
            </div>
            <div class="password-meter" aria-hidden="true">
              <span class="pw-bar" data-bar="1"></span>
              <span class="pw-bar" data-bar="2"></span>
              <span class="pw-bar" data-bar="3"></span>
              <span class="pw-bar" data-bar="4"></span>
            </div>
            <p class="field-hint" id="pwHint">Gunakan kombinasi panjang + huruf + angka.</p>
          </div>

          <div class="form-group">
            <label for="newRole" class="form-label">Role</label>
            <select id="newRole" name="newRole" class="form-input" required>
              <option value="cashier" selected>Kasir</option>
              <option value="admin">Admin</option>
            </select>
          </div>

          <div class="form-group">
            <label for="newTenant" class="form-label">Tenant / Cabang</label>
            <select id="newTenant" name="newTenant" class="form-input" required>
              ${TenantStore.getAll().map(t => `<option value="${_escape(t.id)}">${_escape(t.name)}</option>`).join('')}
            </select>
          </div>

          <p class="form-error" id="userFormError" role="alert" hidden></p>

          <button type="submit" class="btn btn-primary btn-large" id="userSubmitBtn">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
              <circle cx="8.5" cy="7" r="4"></circle>
              <line x1="20" y1="8" x2="20" y2="14"></line>
              <line x1="23" y1="11" x2="17" y2="11"></line>
            </svg>
            Simpan User
          </button>
        </form>
      </section>

      <!-- ============ DAFTAR USER ============ -->
      <section class="activity-card" aria-label="Daftar user terdaftar">
        <h2 class="section-title" style="margin-bottom:16px;">User Terdaftar</h2>
        <ul class="user-list" id="userList">
          <li class="user-list-empty">Memuat daftar user…</li>
        </ul>
        <p class="field-hint" style="margin-top:12px;">
          🔒 Password tidak pernah tampil atau bisa dilihat siapa pun — hanya disimpan sebagai hash.
        </p>
      </section>
    </div>
  `;
}

// Dipanggil router setelah HTML dirender
export function initUsersPage() {
  const form = document.getElementById('userForm');
  if (!form) return;

  _renderUserList();
  _bindUserForm(form);
  _bindPasswordToggle();
}

async function _renderUserList() {
  const listEl = document.getElementById('userList');
  if (!listEl) return;

  const result = await Auth.listUsers();

  if (!result.success) {
    listEl.innerHTML = `<li class="user-list-empty">${_escape(result.error)}</li>`;
    return;
  }

  const tenants = TenantStore.getAll();
  const tenantName = (id) => (tenants.find(t => t.id === id) || { name: id }).name;

  if (!result.users.length) {
    listEl.innerHTML = '<li class="user-list-empty">Belum ada user.</li>';
    return;
  }

  listEl.innerHTML = result.users.map(u => `
    <li class="user-row">
      <span class="user-avatar" aria-hidden="true">${_escape(u.avatar)}</span>
      <div class="user-meta">
        <p class="user-name">${_escape(u.name)}</p>
        <p class="user-sub">${_escape(u.username)} · ${_escape(tenantName(u.tenant))}</p>
      </div>
      <span class="role-badge ${u.role === 'admin' ? 'role-admin' : 'role-cashier'}">${_escape(_roleLabel(u.role))}</span>
      ${u.username === ((Auth.getCurrentUser() || {}).username)
        ? '<span class="user-you">Anda</span>'
        : `<button type="button" class="user-delete" data-delete-user="${_escape(u.username)}" aria-label="Hapus user ${_escape(u.username)}">
             <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
               <polyline points="3 6 5 6 21 6"></polyline>
               <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
             </svg>
           </button>`}
    </li>
  `).join('');

  // Hapus user (dengan konfirmasi modal)
  listEl.querySelectorAll('[data-delete-user]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const uname = btn.dataset.deleteUser;
      const confirmed = await UI.modal({
        title: 'Hapus User',
        message: `Yakin ingin menghapus akun "${uname}"? Tindakan ini tidak bisa dibatalkan.`,
        icon: 'danger',
        confirmText: 'Ya, Hapus',
        cancelText: 'Batal',
        variant: 'danger'
      });
      if (!confirmed) return;

      const res = await Auth.deleteUser(uname);
      if (res.success) {
        UI.toast(`User "${uname}" dihapus`, { type: 'success' });
        _renderUserList();
      } else {
        UI.toast(res.error, { type: 'danger' });
      }
    });
  });
}

function _bindUserForm(form) {
  const pwInput = form.querySelector('#newPassword');
  const bars = form.querySelectorAll('.pw-bar');
  const hint = form.querySelector('#pwHint');
  const errorEl = form.querySelector('#userFormError');
  const submitBtn = form.querySelector('#userSubmitBtn');

  // Password strength meter (UX saja — validasi asli tetap di Auth.createUser)
  pwInput.addEventListener('input', () => {
    const val = pwInput.value;
    let score = 0;
    if (val.length >= 8) score++;
    if (val.length >= 12) score++;
    if (/[A-Za-z]/.test(val) && /[0-9]/.test(val)) score++;
    if (/[^A-Za-z0-9]/.test(val)) score++;
    bars.forEach((bar, i) => { bar.dataset.active = i < score ? '1' : '0'; });
    hint.textContent = score <= 1 ? 'Lemah — tambah panjang & kombinasi.'
                     : score === 2 ? 'Cukup.'
                     : score === 3 ? 'Kuat.' : 'Sangat kuat.';
  });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorEl.hidden = true;

    const name = form.querySelector('#newName').value.trim();
    const username = form.querySelector('#newUsername').value.trim().toLowerCase();
    const password = pwInput.value;
    const role = form.querySelector('#newRole').value;
    const tenant = form.querySelector('#newTenant').value;

    if (!name || !username || !password) {
      errorEl.textContent = 'Semua field wajib diisi.';
      errorEl.hidden = false;
      return;
    }

    submitBtn.disabled = true;
    submitBtn.setAttribute('aria-busy', 'true');

    try {
      const result = await Auth.createUser({ username, password, name, role, tenant });

      if (result.success) {
        UI.toast(`User "${result.user.name}" berhasil dibuat`, { type: 'success' });
        form.reset();
        bars.forEach(b => { b.dataset.active = '0'; });
        hint.textContent = 'Gunakan kombinasi panjang + huruf + angka.';
        _renderUserList();
      } else {
        errorEl.textContent = result.error;
        errorEl.hidden = false;
      }
    } catch (err) {
      errorEl.textContent = 'Terjadi kesalahan. Coba lagi.';
      errorEl.hidden = false;
    } finally {
      submitBtn.disabled = false;
      submitBtn.removeAttribute('aria-busy');
    }
  });
}

function _bindPasswordToggle() {
  const toggle = document.getElementById('pwToggle');
  const input = document.getElementById('newPassword');
  if (!toggle || !input) return;

  toggle.addEventListener('click', () => {
    const showing = input.type === 'text';
    input.type = showing ? 'password' : 'text';
    toggle.setAttribute('aria-label', showing ? 'Tampilkan password' : 'Sembunyikan password');
    toggle.classList.toggle('active', !showing);
    input.focus();
  });
}