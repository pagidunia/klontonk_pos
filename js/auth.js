// ============ AUTHENTICATION SYSTEM ============
// Dummy user database stored in JavaScript
const DUMMY_USERS = {
  // Admin Pusat
  admin: {
    id: 'usr_001',
    username: 'admin',
    password: 'admin123',
    name: 'Admin Pusat',
    role: 'admin',
    avatar: 'A',
    tenant: 'T001'
  },
  // Kasir Warung Merah
  kasir_merah: {
    id: 'usr_002',
    username: 'kasir_merah',
    password: 'kasir123',
    name: 'Kasir Warung Merah',
    role: 'cashier',
    avatar: 'K',
    tenant: 'T002'
  },
  // Kasir Warung Putih
  kasir_putih: {
    id: 'usr_003',
    username: 'kasir_putih',
    password: 'kasir123',
    name: 'Kasir Warung Putih',
    role: 'cashier',
    avatar: 'K',
    tenant: 'T003'
  }
};

class AuthManager {
  constructor() {
    this.currentUser = null;
    this.callbacks = [];
    this.loadSession();
  }

  // Load session dari localStorage jika ada
  loadSession() {
    const stored = localStorage.getItem('klontonk_session');
    if (stored) {
      try {
        this.currentUser = JSON.parse(stored);
      } catch (e) {
        this.currentUser = null;
        localStorage.removeItem('klontonk_session');
      }
    }
  }

  // Login dengan username & password
  login(username, password) {
    const user = DUMMY_USERS[username];

    if (!user) {
      return { success: false, error: 'Username tidak ditemukan' };
    }

    if (user.password !== password) {
      return { success: false, error: 'Password salah' };
    }

    // Store user (tanpa password) ke localStorage
    const sessionData = {
      id: user.id,
      username: user.username,
      name: user.name,
      role: user.role,
      avatar: user.avatar,
      tenant: user.tenant,
      loginTime: new Date().toISOString()
    };

    this.currentUser = sessionData;
    localStorage.setItem('klontonk_session', JSON.stringify(sessionData));

    this.notifySubscribers();
    return { success: true, user: this.currentUser };
  }

  // Logout
  logout() {
    this.currentUser = null;
    localStorage.removeItem('klontonk_session');
    this.notifySubscribers();
  }

  // Check apakah user sudah login
  isAuthenticated() {
    return this.currentUser !== null;
  }

  // Get current user
  getCurrentUser() {
    return this.currentUser;
  }

  // Subscribe ke perubahan auth state
  subscribe(callback) {
    this.callbacks.push(callback);
    return () => {
      this.callbacks = this.callbacks.filter(cb => cb !== callback);
    };
  }

  notifySubscribers() {
    this.callbacks.forEach(cb => cb(this.currentUser));
  }

  // Get dummy users untuk testing (password hidden)
  getDummyUsers() {
    return Object.values(DUMMY_USERS).map(user => ({
      username: user.username,
      name: user.name,
      role: user.role
    }));
  }
}

export const Auth = new AuthManager();
