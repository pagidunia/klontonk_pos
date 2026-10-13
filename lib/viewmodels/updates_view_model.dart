import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../data/models/models.dart';
import '../data/repositories/update_repository.dart';

const updateKinds = {'update': 'Perubahan Terbaru', 'maintenance': 'Maintenance'};

const updateColors = [Option('#16A34A', 'Hijau'), Option('#DC2626', 'Merah'), Option('#0060AF', 'Biru'), Option('#F59E0B', 'Kuning')];

final _colorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
const _maxTitle = 80;
const _maxDesc = 300;

const _defaults = [
  AppUpdate(id: 'd1', kind: 'update', color: '#16A34A', title: 'Mode Terang Baru', description: 'Palet krem hangat yang lebih nyaman dibaca sepanjang hari.'),
  AppUpdate(id: 'd2', kind: 'update', color: '#DC2626', title: 'Tombol Logout Lebih Kontras', description: 'Sekarang tampil solid merah — lebih mudah ditemukan, lebih sulit salah tekan.'),
  AppUpdate(id: 'd3', kind: 'update', color: '#0060AF', title: 'Aplikasi Mobile', description: 'Kini tersedia sebagai aplikasi Android dan iOS dengan scan barcode kamera.'),
  AppUpdate(id: 'd5', kind: 'maintenance', color: '#0060AF', title: 'Maintenance Terjadwal', description: 'Minggu, 02.00–03.00 WIB — sebagian fitur mungkin tidak tersedia sementara.'),
];

/// Validasi tampilan; batasan yang sama diulang oleh database. Mengembalikan pesan galat atau null.
String? validateUpdate({required String kind, required String title, required String description, required String color}) {
  if (!updateKinds.containsKey(kind)) return 'Jenis tidak valid.';
  final t = title.trim();
  if (t.isEmpty) return 'Judul wajib diisi.';
  if (t.length > _maxTitle) return 'Judul maksimal $_maxTitle karakter.';
  if (description.trim().length > _maxDesc) return 'Deskripsi maksimal $_maxDesc karakter.';
  if (!_colorPattern.hasMatch(color)) return 'Warna tidak valid.';
  return null;
}

/// Info update & jadwal maintenance (tabel `app_updates`). Semua user boleh membaca; hanya admin yang
/// mengubah (dijaga RLS). Sebelum termuat / saat offline dipakai daftar bawaan.
class UpdatesViewModel extends ChangeNotifier {
  UpdatesViewModel(this._repo);
  final UpdateRepository _repo;

  List<AppUpdate> _rows = _defaults;

  List<AppUpdate> list(String kind) => _rows.where((r) => r.kind == kind).toList();

  String _describe(AppError e) => describeError(e, forbidden: 'Hanya Admin yang boleh mengubah info update.');

  /// Mengembalikan pesan galat atau null.
  Future<String?> load() async {
    final result = await _repo.list();
    switch (result) {
      case Err(:final error):
        return _describe(error);
      case Ok(:final data):
        if (data.isNotEmpty) _rows = data;
        notifyListeners();
        return null;
    }
  }

  Future<String?> _then(Result<void> result) async {
    if (result case Err(:final error)) return _describe(error);
    return load();
  }

  Future<String?> add({required String kind, required String title, required String description, required String color}) async {
    final invalid = validateUpdate(kind: kind, title: title, description: description, color: color);
    if (invalid != null) return invalid;
    final sortOrder = _rows.where((r) => r.kind == kind).length + 1;
    return _then(await _repo.add(kind: kind, title: title.trim(), description: description.trim().isEmpty ? null : description.trim(), color: color, sortOrder: sortOrder));
  }

  Future<String?> edit(String id, {required String kind, required String title, required String description, required String color}) async {
    final invalid = validateUpdate(kind: kind, title: title, description: description, color: color);
    if (invalid != null) return invalid;
    return _then(await _repo.update(id, kind: kind, title: title.trim(), description: description.trim().isEmpty ? null : description.trim(), color: color));
  }

  Future<String?> remove(String id) async => _then(await _repo.remove(id));
}
