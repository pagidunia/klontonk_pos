import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan kunci-nilai sinkron di perangkat. Dibuat satu kali di main() setelah
/// SharedPreferences siap, lalu disuntikkan ke semua yang membutuhkan (mudah diganti saat tes).
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
  Iterable<String> get keys;
}

class PrefsStore implements KeyValueStore {
  PrefsStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);

  @override
  Future<bool> remove(String key) => _prefs.remove(key);

  @override
  Iterable<String> get keys => _prefs.getKeys();
}

/// Untuk tes dan cadangan bila penyimpanan perangkat tidak bisa dipakai.
class MemoryStore implements KeyValueStore {
  final _data = <String, String>{};

  @override
  String? getString(String key) => _data[key];

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Iterable<String> get keys => _data.keys.toList();
}

/// Baca JSON dari penyimpanan; nilai rusak dianggap kosong.
Object? readJson(KeyValueStore store, String key) {
  final raw = store.getString(key);
  if (raw == null) return null;
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

Future<bool> writeJson(KeyValueStore store, String key, Object value) async {
  try {
    return await store.setString(key, jsonEncode(value));
  } catch (_) {
    return false;
  }
}
