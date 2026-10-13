import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/result.dart';
import '../data/models/models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/user_repository.dart';
import '../services/services.dart';
import 'session_view_model.dart';

final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,24}$');

/// Pesan galat pertama dari aturan akun baru, atau null bila lolos.
String? validateNewUser({required String username, required String password, required String name, required String role, required String tenant}) {
  final uname = username.trim().toLowerCase();
  final nama = name.trim();
  if (uname.isEmpty || password.isEmpty || nama.isEmpty) return 'Semua field wajib diisi.';
  if (!_usernamePattern.hasMatch(uname)) return 'Username 3–24 karakter, hanya huruf kecil, angka, titik, underscore.';
  if (nama.length > 60) return 'Nama maksimal 60 karakter.';
  if (password.length < 8) return 'Password minimal 8 karakter.';
  if (password.length > 128) return 'Password maksimal 128 karakter.';
  if (!RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'[0-9]').hasMatch(password)) return 'Password harus mengandung huruf dan angka.';
  if (password.toLowerCase().contains(uname)) return 'Password tidak boleh mengandung username.';
  if (!['admin', 'cashier'].contains(role)) return 'Role tidak valid.';
  if (!RegExp(r'^T\d{3}$').hasMatch(tenant)) return 'Tenant tidak valid.';
  return null;
}

/// Kekuatan password 0..4 untuk indikator.
int passwordStrength(String password) {
  var skor = 0;
  if (password.length >= 8) skor++;
  if (password.length >= 12) skor++;
  if (RegExp(r'[A-Za-z]').hasMatch(password) && RegExp(r'[0-9]').hasMatch(password)) skor++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password) || (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password))) skor++;
  return skor;
}

/// Manajemen akun (khusus admin). Akun dibuat lewat signUp terpisah (sesi admin tidak berubah),
/// lalu profilnya ditulis admin. Akun tanpa profil tidak punya akses apa pun, jadi kegagalan di
/// tengah jalan aman.
class UsersViewModel extends ChangeNotifier {
  UsersViewModel({required this.repo, required this.auth, required this.session, required this.toast, required this.confirm});
  final UserRepository repo;
  final AuthRepository auth;
  final SessionViewModel session;
  final ToastService toast;
  final Future<bool> Function({required String title, required String message}) confirm;

  List<AppUser> users = const [];
  bool loading = true;
  String? loadError;
  bool saving = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final result = await repo.list();
    switch (result) {
      case Err(:final error):
        if (error.expired) session.expire();
        loadError = _describe(error);
      case Ok(:final data):
        users = data;
        loadError = null;
    }
    loading = false;
    notifyListeners();
  }

  String _describe(AppError e) => e.status == 403 || e.code == '42501' ? 'Akses ditolak. Fitur ini hanya untuk Admin.' : describeError(e);

  /// Membuat akun. Mengembalikan pesan galat atau null.
  Future<String?> create({required String username, required String password, required String name, required String role, required String tenant}) async {
    if (!session.isAdmin) return 'Akses ditolak. Fitur ini hanya untuk Admin.';
    final invalid = validateNewUser(username: username, password: password, name: name, role: role, tenant: tenant);
    if (invalid != null) return invalid;
    if (saving) return null;

    saving = true;
    notifyListeners();
    try {
      final uname = username.trim().toLowerCase();
      final nama = name.trim();

      final taken = await repo.usernameTaken(uname);
      if (taken case Err(:final error)) return _describe(error);
      if ((taken as Ok<bool>).data) return 'Username sudah digunakan.';

      final signUp = await auth.signUpDetached('$uname@${AppConfig.emailDomain}', password);
      if (signUp case Err(:final error)) {
        if (error.code == 'user_already_exists' || error.status == 422 || RegExp('duplicate|already', caseSensitive: false).hasMatch(error.message)) {
          return 'Username ini sudah pernah dipakai. Gunakan username lain.';
        }
        return error.message;
      }
      final uid = (signUp as Ok<String>).data;

      final saved = await repo.insertProfile(id: uid, username: uname, name: nama, role: role, avatar: String.fromCharCodes(nama.runes.take(1)).toUpperCase(), tenantId: tenant);
      if (saved case Err(:final error)) return _describe(error);

      toast.show('User "$uname" berhasil dibuat.', type: ToastType.success);
      await load();
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> delete(AppUser user) async {
    final yakin = await confirm(title: 'Hapus User', message: 'Hapus akun "${user.username}"? Akun tidak akan bisa login lagi.');
    if (!yakin) return;
    final result = await repo.delete(user.username);
    if (result case Err(:final error)) {
      toast.show(_describe(error), type: ToastType.danger, duration: const Duration(seconds: 6));
      return;
    }
    toast.show('User dihapus.', type: ToastType.success);
    await load();
  }
}
