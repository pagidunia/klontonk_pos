import 'package:flutter/foundation.dart';

import '../data/local/local_stores.dart';
import '../data/models/models.dart';
import '../services/services.dart';

/// Catatan kasir (serah terima shift). Hanya di perangkat ini, tidak dikirim ke database.
class CatatanViewModel extends ChangeNotifier {
  CatatanViewModel({required NotesStore notes, required this.toast}) : _notes = notes;
  final NotesStore _notes;
  final ToastService toast;

  List<Note> get notes => _notes.list();

  /// Mengembalikan pesan galat atau null.
  Future<String?> add(String text) async {
    final error = await _notes.add(text);
    if (error != null) return error;
    toast.show('Catatan disimpan.', type: ToastType.success);
    notifyListeners();
    return null;
  }

  Future<void> remove(String id) async {
    await _notes.remove(id);
    notifyListeners();
  }
}
