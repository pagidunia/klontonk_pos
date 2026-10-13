import '../models/models.dart';
import 'key_value_store.dart';

/// Antrean penjualan offline (disimpan di perangkat sampai berhasil dikirim). Tidak menyentuh jaringan.
class OutboxStore {
  OutboxStore(this._store);
  final KeyValueStore _store;

  static const key = 'klontonk:outbox:v1';
  static const maxPending = 200;

  List<OutboxEntry> list() {
    final data = readJson(_store, key);
    if (data is! List) return [];
    final hasil = <OutboxEntry>[];
    for (final item in data) {
      try {
        hasil.add(OutboxEntry.fromJson(Map<String, dynamic>.from(item as Map)));
      } catch (_) {
        // entri rusak dilewati
      }
    }
    return hasil;
  }

  Future<bool> _write(List<OutboxEntry> entries) => writeJson(_store, key, entries.map((e) => e.toJson()).toList());

  /// ok=true bila tersimpan (atau sudah ada); penyimpanan penuh tidak melempar error.
  Future<({bool ok, String? error})> add(OutboxEntry entry) async {
    final current = list();
    if (current.any((e) => e.clientId == entry.clientId)) return (ok: true, error: null);
    if (current.length >= maxPending) return (ok: false, error: 'Antrean offline penuh ($maxPending penjualan). Sambungkan internet dulu agar terkirim.');
    final saved = await _write([...current, entry]);
    return saved ? (ok: true, error: null) : (ok: false, error: 'Penyimpanan perangkat penuh; penjualan offline tidak bisa disimpan.');
  }

  Future<void> remove(String clientId) => _write(list().where((e) => e.clientId != clientId).toList());

  Future<void> update(String clientId, OutboxEntry Function(OutboxEntry) change) => _write(list().map((e) => e.clientId == clientId ? change(e) : e).toList());

  int count([String? status]) => list().where((e) => status == null || e.status == status).length;
}

/// Salinan data terakhir yang berhasil dimuat (stok) agar aplikasi tetap bisa dipakai berjualan saat
/// offline. BUKAN sumber kebenaran. Dihapus saat logout; antrean offline sengaja TIDAK ikut terhapus.
class SnapshotStore {
  SnapshotStore(this._store);
  final KeyValueStore _store;

  static const prefix = 'klontonk:snapshot:';

  Future<bool> save(String name, Object data, [DateTime? now]) => writeJson(_store, '$prefix$name', {'at': (now ?? DateTime.now()).toIso8601String(), 'data': data});

  ({Object data, DateTime at})? load(String name) {
    final parsed = readJson(_store, '$prefix$name');
    if (parsed is! Map || !parsed.containsKey('data') || parsed['at'] == null) return null;
    final at = DateTime.tryParse(parsed['at'] as String);
    if (at == null) return null;
    return (data: parsed['data'] as Object, at: at);
  }

  Future<void> clearAll() async {
    for (final k in _store.keys.where((k) => k.startsWith(prefix)).toList()) {
      await _store.remove(k);
    }
  }
}

/// Catatan kasir, hanya di perangkat ini.
class NotesStore {
  NotesStore(this._store);
  final KeyValueStore _store;

  static const key = 'klontonk:notes:v1';
  static const maxNotes = 100;
  static const maxLength = 500;

  List<Note> list() {
    final data = readJson(_store, key);
    if (data is! List) return [];
    final hasil = <Note>[];
    for (final item in data) {
      try {
        hasil.add(Note.fromJson(Map<String, dynamic>.from(item as Map)));
      } catch (_) {}
    }
    hasil.sort((a, b) => b.at.compareTo(a.at));
    return hasil;
  }

  Future<bool> _write(List<Note> notes) => writeJson(_store, key, notes.map((n) => n.toJson()).toList());

  /// Mengembalikan pesan galat, atau null bila berhasil.
  Future<String?> add(String text, [DateTime? now]) async {
    final bersih = text.trim();
    if (bersih.isEmpty) return 'Catatan tidak boleh kosong.';
    if (bersih.length > maxLength) return 'Catatan maksimal $maxLength karakter.';
    final current = list();
    if (current.length >= maxNotes) return 'Jumlah catatan sudah penuh ($maxNotes). Hapus catatan lama dulu.';
    final waktu = now ?? DateTime.now();
    final id = 'n_${waktu.microsecondsSinceEpoch.toRadixString(36)}';
    final saved = await _write([...current, Note(id: id, text: bersih, at: waktu)]);
    return saved ? null : 'Penyimpanan perangkat penuh; catatan tidak tersimpan.';
  }

  Future<void> remove(String id) => _write(list().where((n) => n.id != id).toList());
}

/// Preferensi sederhana: tema, cetak otomatis, tenant terakhir, pembatas percobaan login.
class PreferencesStore {
  PreferencesStore(this._store);
  final KeyValueStore _store;

  static const themeKey = 'klontonk:theme';
  static const autoPrintKey = 'klontonk:autoprint';
  static const scanFrontKey = 'klontonk:scan_front';
  static const tenantKey = 'klontonk:tenant';
  static const throttleKey = 'klontonk:auth_throttle';
  static const activityKey = 'klontonk:last_activity';

  /// 'light' | 'dark' | null (ikut sistem)
  String? get theme => _store.getString(themeKey);
  Future<void> setTheme(String value) => _store.setString(themeKey, value);

  /// Kamera scan barcode: true = kamera depan, false (bawaan) = kamera belakang.
  bool get scanFront => _store.getString(scanFrontKey) == '1';
  Future<void> setScanFront(bool front) => _store.setString(scanFrontKey, front ? '1' : '0');

  bool get autoPrint => _store.getString(autoPrintKey) == '1';
  Future<void> setAutoPrint(bool on) => _store.setString(autoPrintKey, on ? '1' : '0');

  Future<void> setTenant(String id) => _store.setString(tenantKey, id);

  ({int count, int lockedUntil}) get throttle {
    final data = readJson(_store, throttleKey);
    if (data is Map) return (count: (data['count'] as num?)?.toInt() ?? 0, lockedUntil: (data['lockedUntil'] as num?)?.toInt() ?? 0);
    return (count: 0, lockedUntil: 0);
  }

  Future<void> setThrottle(int count, int lockedUntil) => writeJson(_store, throttleKey, {'count': count, 'lockedUntil': lockedUntil});
  Future<void> resetThrottle() => _store.remove(throttleKey);

  DateTime? get lastActivity {
    final ms = int.tryParse(_store.getString(activityKey) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> touchActivity([DateTime? now]) => _store.setString(activityKey, (now ?? DateTime.now()).millisecondsSinceEpoch.toString());
  Future<void> clearActivity() => _store.remove(activityKey);
}

