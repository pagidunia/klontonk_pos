import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';

const profileColumns = 'id,username,name,role,avatar,tenant:tenant_id';

/// Akses Supabase Auth + tabel `profiles`. Keputusan akses sesungguhnya ada di database (RLS);
/// pengecekan di aplikasi hanya untuk tampilan.
class AuthRepository {
  AuthRepository(this._db, this._detached);
  final SupabaseClient _db;

  /// Klien tanpa sesi: membuat akun baru TANPA mengganti sesi admin yang sedang aktif.
  final SupabaseClient Function() _detached;

  /// Sesi disimpan di perangkat sehingga tetap terbaca saat offline.
  String? get currentUserId => _db.auth.currentSession?.user.id;
  bool get hasSession => _db.auth.currentSession != null;

  Stream<AuthChangeEvent> get events => _db.auth.onAuthStateChange.map((s) => s.event);

  Future<Result<String>> signIn(String email, String password) => guard(() async {
        final res = await _db.auth.signInWithPassword(email: email, password: password);
        final user = res.user;
        if (user == null) throw const AuthException('Login gagal. Coba lagi.', statusCode: '500');
        return user.id;
      });

  /// Keluar dari perangkat ini saja, agar sesi di perangkat lain tidak ikut terputus.
  Future<void> signOut() async {
    try {
      await _db.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // offline: sesi lokal tetap dibuang
    }
  }

  Future<Result<Map<String, dynamic>?>> fetchProfile(String uid) => guard(() => _db.from('profiles').select(profileColumns).eq('id', uid).maybeSingle());

  Future<Result<String>> signUpDetached(String email, String password) => guard(() async {
        final res = await _detached().auth.signUp(email: email, password: password);
        final user = res.user;
        if (user == null) throw const AuthException('Akun gagal dibuat. Coba lagi.', statusCode: '500');
        return user.id;
      });
}
