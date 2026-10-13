import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../data/models/models.dart';
import '../data/repositories/update_repository.dart';

const updateKinds = {'update': 'Perubahan Terbaru', 'maintenance': 'Maintenance'};

/// Info update & jadwal maintenance (tabel `app_updates` di Supabase), hanya dibaca. Tidak ada isi
/// bawaan di kode: sebelum termuat / saat offline daftar kosong.
class UpdatesViewModel extends ChangeNotifier {
  UpdatesViewModel(this._repo);
  final UpdateRepository _repo;

  List<AppUpdate> _rows = const [];

  List<AppUpdate> list(String kind) => _rows.where((r) => r.kind == kind).toList();

  /// Mengembalikan pesan galat atau null.
  Future<String?> load() async {
    final result = await _repo.list();
    switch (result) {
      case Err(:final error):
        return describeError(error);
      case Ok(:final data):
        _rows = data;
        notifyListeners();
        return null;
    }
  }
}
