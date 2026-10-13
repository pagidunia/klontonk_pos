import 'package:flutter/foundation.dart';

import '../data/models/models.dart';
import '../services/services.dart';
import 'session_view_model.dart';
import 'updates_view_model.dart';

/// Info Update: semua pengguna membaca; admin boleh menambah/ubah/hapus.
class InfoUpdateViewModel extends ChangeNotifier {
  InfoUpdateViewModel({required this.updates, required this.session, required this.toast, required this.confirm});
  final UpdatesViewModel updates;
  final SessionViewModel session;
  final ToastService toast;
  final Future<bool> Function({required String title, required String message}) confirm;

  String? editingId;
  String? loadError;

  bool get isAdmin => session.isAdmin;

  Future<void> load() async {
    loadError = await updates.load();
    notifyListeners();
  }

  void startEdit(String? id) {
    editingId = id;
    notifyListeners();
  }

  AppUpdate? get editing => editingId == null ? null : [...updates.list('update'), ...updates.list('maintenance')].where((r) => r.id == editingId).firstOrNull;

  /// Simpan (tambah bila tidak sedang mengedit). Mengembalikan pesan galat atau null.
  Future<String?> save({required String kind, required String title, required String description, required String color}) async {
    final id = editingId;
    final error = id == null ? await updates.add(kind: kind, title: title, description: description, color: color) : await updates.edit(id, kind: kind, title: title, description: description, color: color);
    if (error != null) return error;
    toast.show(id == null ? 'Info ditambahkan.' : 'Info diperbarui.', type: ToastType.success);
    editingId = null;
    notifyListeners();
    return null;
  }

  Future<void> remove(AppUpdate row) async {
    final yakin = await confirm(title: 'Hapus Info', message: 'Hapus "${row.title}"?');
    if (!yakin) return;
    final error = await updates.remove(row.id);
    toast.show(error ?? 'Info dihapus.', type: error == null ? ToastType.success : ToastType.danger);
    if (editingId == row.id) editingId = null;
    notifyListeners();
  }
}
