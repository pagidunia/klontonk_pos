import { UI } from './ui.js';

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
    this.updateActivityBound = this.updateActivity.bind(this);
    this.timeoutInterval = null;
    this.loadSession();
    if (this.isAuthenticated()) {
      this.setupActivityListeners();
      this.startTimeoutCheck();
    }
  }

  // Load session dari localStorage jika ada dengan pengecekan timeout
  loadSession() {
    const stored = localStorage.getItem('klontonk_session');
    if (stored) {
      try {
        const lastActivity = parseInt(localStorage.getItem('klontonk_last_activity') || '0', 10);
        const now = Date.now();
        const timeoutDuration = 30 * 60 * 1000; // 30 menit

        if (lastActivity && (now - lastActivity > timeoutDuration)) {
          // Session expired
          localStorage.removeItem('klontonk_session');
          localStorage.removeItem('klontonk_last_activity');
          this.currentUser = null;
        } else {
          this.currentUser = JSON.parse(stored);
          // Set aktivitas terakhir ke waktu sekarang untuk sesi yang baru dimuat
          localStorage.setItem('klontonk_last_activity', now.toString());
        }
      } catch (e) {
        this.currentUser = null;
        localStorage.removeItem('klontonk_session');
        localStorage.removeItem('klontonk_last_activity');
      }
    }
  }

  // Update aktivitas terakhir (dengan throttle 5 detik agar efisien)
  updateActivity() {
    if (!this.isAuthenticated()) return;
    const now = Date.now();
    const lastUpdate = parseInt(localStorage.getItem('klontonk_last_activity') || '0', 10);
    if (now - lastUpdate > 5000) {
      localStorage.setItem('klontonk_last_activity', now.toString());
    }
  }

  // Daftarkan event listener untuk interaksi pengguna
  setupActivityListeners() {
    const events = ['mousemove', 'mousedown', 'keypress', 'scroll', 'touchstart'];
    events.forEach(event => {
      window.addEventListener(event, this.updateActivityBound, { passive: true });
    });
  }

  // Hentikan event listener interaksi
  removeActivityListeners() {
    const events = ['mousemove', 'mousedown', 'keypress', 'scroll', 'touchstart'];
    events.forEach(event => {
      window.removeEventListener(event, this.updateActivityBound, { passive: true });
    });
  }

  // Periksa timeout session secara berkala (setiap 10 detik)
  startTimeoutCheck() {
    if (this.timeoutInterval) clearInterval(this.timeoutInterval);
    
    this.timeoutInterval = setInterval(() => {
      if (!this.isAuthenticated()) {
        clearInterval(this.timeoutInterval);
        return;
      }
      
      const lastActivity = parseInt(localStorage.getItem('klontonk_last_activity') || '0', 10);
      const now = Date.now();
      const timeoutDuration = 30 * 60 * 1000; // 30 menit
      
      if (lastActivity && (now - lastActivity > timeoutDuration)) {
        this.logout();
        clearInterval(this.timeoutInterval);
        
        UI.modal({
          title: 'Sesi Berakhir',
          message: 'Sesi Anda telah berakhir karena tidak ada aktivitas selama 30 menit. Silakan masuk kembali.',
          icon: 'warning',
          confirmText: 'OK',
          variant: 'primary'
        }).then(() => {
          window.location.reload();
        });
      }
    }, 10000);
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
    localStorage.setItem('klontonk_last_activity', Date.now().toString());

    this.setupActivityListeners();
    this.startTimeoutCheck();

    this.notifySubscribers();
    return { success: true, user: this.currentUser };
  }

  // Logout
  logout() {
    this.currentUser = null;
    localStorage.removeItem('klontonk_session');
    localStorage.removeItem('klontonk_last_activity');
    if (this.timeoutInterval) {
      clearInterval(this.timeoutInterval);
    }
    this.removeActivityListeners();
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
