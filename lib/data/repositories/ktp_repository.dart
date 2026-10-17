import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';

/// Foto KTP pelanggan utang di bucket PRIVAT `ktp` (data pribadi: tidak publik; akses dijaga RLS per tenant).
/// Path berbentuk `<tenant>/<uuid>.jpg`.
class KtpRepository {
  KtpRepository(this._db);
  final SupabaseClient _db;

  static const bucket = 'ktp';

  Future<Result<void>> upload(String path, Uint8List bytes) => guard(() async {
        await _db.storage.from(bucket).uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
      });

  /// Pembersihan bila penjualan gagal setelah foto terunggah (best effort).
  Future<void> remove(String path) async {
    try {
      await _db.storage.from(bucket).remove([path]);
    } catch (_) {
      // gagal bersih-bersih tidak boleh menutupi galat utama
    }
  }
}
