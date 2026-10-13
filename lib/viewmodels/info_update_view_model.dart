import 'package:flutter/foundation.dart';

import 'updates_view_model.dart';

/// Info Update (hanya lihat): memuat daftar dari Supabase dan menampilkannya.
class InfoUpdateViewModel extends ChangeNotifier {
  InfoUpdateViewModel({required this.updates});
  final UpdatesViewModel updates;

  String? loadError;

  Future<void> load() async {
    loadError = await updates.load();
    notifyListeners();
  }
}
