import 'package:flutter/material.dart';

import '../data/local/local_stores.dart';

class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel(this._prefs) {
    final saved = _prefs.theme;
    mode = saved == 'dark' ? ThemeMode.dark : (saved == 'light' ? ThemeMode.light : ThemeMode.system);
  }

  final PreferencesStore _prefs;
  late ThemeMode mode;

  void set(ThemeMode next) {
    mode = next;
    _prefs.setTheme(next == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }
}
