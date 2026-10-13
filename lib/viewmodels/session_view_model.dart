import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/result.dart';
import '../data/local/key_value_store.dart';
import '../data/local/local_stores.dart';
import '../data/models/models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/role_menu_repository.dart';
import '../data/repositories/tenant_repository.dart';
import '../domain/permissions.dart';
import '../services/services.dart';

enum AuthStatus { loading, anonymous, authenticated }

sealed class LoginResult {
  const LoginResult();
}

final class LoginOk extends LoginResult {
  const LoginOk();
}

final class LoginFail extends LoginResult {
  const LoginFail(this.error, {this.locked = false});
  final String error;
  final bool locked;
}

final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,24}$');
const _sessionKey = 'klontonk_session';
const _menusKey = 'klontonk_role_menus';
const _tenantsKey = 'klontonk_tenants';

/// Login memakai Supabase Auth (email + password); username dipetakan ke <username>@klontonk.local.
/// Peran dan tenant tiap akun ada di tabel `profiles`. Keputusan akses dijaga RLS di database;
/// pengecekan di sini hanya untuk tampilan.
///
/// - Pesan galat login selalu generik (mencegah user enumeration).
/// - Percobaan gagal dibatasi dengan exponential backoff di perangkat; Supabase Auth membatasi di server.
/// - Sesi yang sudah masuk tetap dibuka saat offline; login baru butuh koneksi.
/// - Sesi ditutup setelah 30 menit tanpa aktivitas.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel({required AuthRepository auth, required TenantRepository tenants, required RoleMenuRepository roleMenus, required PreferencesStore prefs, required KeyValueStore store, required SnapshotStore snapshots, required ToastService toast, DateTime Function()? clock})
      : _auth = auth,
        _tenantRepo = tenants,
        _roleMenuRepo = roleMenus,
        _prefs = prefs,
        _store = store,
        _snapshots = snapshots,
        _toast = toast,
        _now = clock ?? DateTime.now;

  final AuthRepository _auth;
  final TenantRepository _tenantRepo;
  final RoleMenuRepository _roleMenuRepo;
  final PreferencesStore _prefs;
  final KeyValueStore _store;
  final SnapshotStore _snapshots;
  final ToastService _toast;
  final DateTime Function() _now;

  AuthStatus status = AuthStatus.loading;
  UserSession? user;

  /// Daftar cabang HANYA dari tabel `tenants` di Supabase (tidak ada daftar tertanam di kode).
  /// Saat offline dipakai salinan terakhir yang pernah dimuat dari Supabase.
  List<Tenant> tenants = const [];
  Tenant? _current;
  StreamSubscription<AuthChangeEvent>? _events;

  /// Dipanggil saat pengguna keluar (mengosongkan data di ViewModel lain).
  final _onLogout = <VoidCallback>[];
  void addLogoutListener(VoidCallback callback) => _onLogout.add(callback);

  /// Cabang aktif. Sebelum daftar termuat, tampil kode cabang akun (mis. T003) sebagai pengganti sementara.
  Tenant get currentTenant => _current ?? Tenant(id: user?.tenantId ?? '', name: user?.tenantId ?? '-');
  String get tenantId => currentTenant.id;
  bool get isAdmin => user?.isAdmin ?? false;
  /// Jatah menu role akun ini dari Supabase (null = belum termuat -> menu terkelola disembunyikan).
  Set<String>? _menus;
  bool get menusLoaded => _menus != null;

  /// Boleh membuka menu [path] menurut jatah role akun yang login.
  bool can(String path) => canOpen(user?.role, path, menuDb: _menus);

  /// Muat jatah menu role dari tabel `role_menus` di Supabase. Gagal / offline: pakai salinan terakhir
  /// yang pernah dimuat dari Supabase; bila belum ada, menu terkelola tidak ditampilkan.
  Future<void> loadMenus() async {
    final role = user?.role;
    if (role == null) return;
    final result = await _roleMenuRepo.menusFor(role);
    switch (result) {
      case Ok(:final data):
        _menus = data;
        await writeJson(_store, _menusKey, {'role': role, 'menus': data.toList()});
        notifyListeners();
      case Err():
        final cached = readJson(_store, _menusKey);
        if (_menus == null && cached is Map && cached['role'] == role && cached['menus'] is List) {
          _menus = (cached['menus'] as List).cast<String>().toSet();
          notifyListeners();
        }
    }
  }

  void _set(AuthStatus next, [UserSession? nextUser]) {
    status = next;
    user = nextUser;
    notifyListeners();
  }

  // ---------- Boot ----------

  /// Pulihkan sesi saat aplikasi dibuka. Sesi hanya valid bila Supabase masih punya sesi, profil
  /// tersimpan ada, dan belum lewat batas tidak-aktif.
  Future<void> boot() async {
    _events ??= _auth.events.listen((event) {
      if (event == AuthChangeEvent.signedOut && status == AuthStatus.authenticated) _clear(silent: true);
    });
    final cached = readJson(_store, _sessionKey);
    final last = _prefs.lastActivity;
    final expired = last != null && _now().difference(last) > AppConfig.sessionTimeout;
    if (cached is! Map || !_auth.hasSession || expired) {
      await _clear();
      return;
    }
    try {
      final restored = UserSession.fromJson(Map<String, dynamic>.from(cached));
      if (restored.id != _auth.currentUserId) {
        await _clear();
        return;
      }
      _restoreTenants();
      _selectTenant(restored.tenantId, notify: false);
      await _prefs.touchActivity(_now());
      _set(AuthStatus.authenticated, restored);
    } catch (_) {
      await _clear();
    }
  }

  Future<void> _clear({bool silent = false}) async {
    await _store.remove(_sessionKey);
    await _store.remove(_menusKey);
    _menus = null;
    await _prefs.clearActivity();
    await _snapshots.clearAll(); // salinan stok offline tidak boleh tertinggal untuk pengguna berikutnya
    for (final callback in _onLogout) {
      callback();
    }
    _set(AuthStatus.anonymous);
    if (!silent) await _auth.signOut();
  }

  // ---------- Pembatas percobaan ----------

  bool get isLockedOut => _prefs.throttle.lockedUntil > _now().millisecondsSinceEpoch;
  int get lockoutSeconds => ((_prefs.throttle.lockedUntil - _now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 1 << 30);

  Future<void> _recordFailure() async {
    final t = _prefs.throttle;
    final count = t.count + 1;
    var lockedUntil = t.lockedUntil;
    // Exponential backoff: 3 gagal -> 30 dtk, 4 -> 1 mnt, 5 -> 2 mnt ... maks 15 menit.
    if (count >= 3) {
      final ms = (30000 * (1 << (count - 3))).clamp(0, 15 * 60 * 1000);
      lockedUntil = _now().millisecondsSinceEpoch + ms;
    }
    await _prefs.setThrottle(count, lockedUntil);
  }

  // ---------- Login / logout ----------

  Future<LoginResult> login(String username, String password) async {
    if (isLockedOut) return LoginFail('Terlalu banyak percobaan. Coba lagi dalam $lockoutSeconds detik.', locked: true);

    final uname = username.trim().toLowerCase();
    if (!_usernamePattern.hasMatch(uname) || password.isEmpty) {
      await _recordFailure();
      return const LoginFail('Username atau password salah.');
    }

    final signedIn = await _auth.signIn('$uname@${AppConfig.emailDomain}', password);
    switch (signedIn) {
      case Err(:final error):
        if (error.status == 429) return const LoginFail('Terlalu banyak percobaan. Coba lagi beberapa saat.', locked: true);
        if (error.isNetwork) return LoginFail(error.message);
        if (error.status >= 500) return const LoginFail('Layanan sedang bermasalah. Coba lagi sebentar.');
        await _recordFailure();
        return const LoginFail('Username atau password salah.');
      case Ok(:final data):
        // Akun Supabase Auth tanpa profil tidak punya akses apa pun.
        final profile = await _auth.fetchProfile(data);
        switch (profile) {
          case Err(:final error):
            await _auth.signOut();
            return LoginFail(error.message);
          case Ok(data: null):
            await _auth.signOut();
            return const LoginFail('Akun ini belum diberi akses. Hubungi admin.');
          case Ok(data: final row?):
            await _prefs.resetThrottle();
            final session = UserSession.fromProfile(row, _now());
            await writeJson(_store, _sessionKey, session.toJson());
            await _prefs.touchActivity(_now());
            _restoreTenants();
            _selectTenant(session.tenantId, notify: false);
            _set(AuthStatus.authenticated, session);
            return const LoginOk();
        }
    }
  }

  Future<void> logout() => _clear();

  /// Sesi tidak berlaku lagi (mis. server menjawab 401).
  void expire() {
    if (status != AuthStatus.authenticated) return;
    _toast.show('Sesi berakhir. Silakan login ulang.', type: ToastType.warning);
    _clear();
  }

  // ---------- Aktivitas ----------

  /// Catat aktivitas (dibatasi tiap 5 detik). Dipanggil saat pengguna menyentuh layar.
  Future<void> touch() async {
    if (status != AuthStatus.authenticated) return;
    final last = _prefs.lastActivity;
    if (last == null || _now().difference(last) > const Duration(seconds: 5)) await _prefs.touchActivity(_now());
  }

  /// Periksa batas tidak-aktif; mengembalikan true bila sesi baru saja ditutup.
  Future<bool> checkInactivity() async {
    if (status != AuthStatus.authenticated) return false;
    final last = _prefs.lastActivity;
    if (last == null || _now().difference(last) <= AppConfig.sessionTimeout) return false;
    await _clear();
    return true;
  }

  // ---------- Tenant ----------

  /// Muat daftar tenant dari database. Gagal/offline: tetap memakai daftar cadangan.
  Future<Result<void>> loadTenants() async {
    final result = await _tenantRepo.list();
    switch (result) {
      case Err(:final error):
        if (tenants.isEmpty) {
          _restoreTenants();
          _reselectCurrent();
          notifyListeners();
        }
        return Err(error);
      case Ok(:final data):
        if (data.isEmpty) return const Err(AppError(status: 0, message: 'Daftar tenant kosong.'));
        tenants = data;
        await writeJson(_store, _tenantsKey, [for (final t in data) {'id': t.id, 'name': t.name}]);
        _reselectCurrent();
        notifyListeners();
        return const Ok(null);
    }
  }

  /// Salinan daftar cabang terakhir yang dimuat dari Supabase (untuk saat offline).
  void _restoreTenants() {
    final cached = readJson(_store, _tenantsKey);
    if (cached is! List) return;
    try {
      tenants = [for (final t in cached) Tenant.fromJson(Map<String, dynamic>.from(t as Map))];
    } catch (_) {
      // salinan rusak: abaikan
    }
  }

  /// Ambil ulang objek cabang aktif dari daftar terbaru, supaya nama terbaru dari database yang tampil.
  void _reselectCurrent() {
    final id = _current?.id ?? user?.tenantId;
    if (id == null) return;
    final found = tenants.where((t) => t.id == id);
    if (found.isNotEmpty) {
      _current = found.first;
    } else if (tenants.isNotEmpty && _current == null) {
      _current = tenants.first;
    }
  }

  void _selectTenant(String id, {bool notify = true}) {
    final found = tenants.where((t) => t.id == id);
    _current = found.isEmpty ? Tenant(id: id, name: id) : found.first;
    _prefs.setTenant(_current!.id);
    if (notify) notifyListeners();
  }

  void setTenant(String id) {
    if (id == _current?.id) return;
    _selectTenant(id);
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }
}
