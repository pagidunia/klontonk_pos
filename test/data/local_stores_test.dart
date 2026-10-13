import 'package:flutter_test/flutter_test.dart';
import 'package:klontonk_pos/data/local/key_value_store.dart';
import 'package:klontonk_pos/data/local/local_stores.dart';

void main() {
  group('NotesStore', () {
    test('menambah, mengurutkan terbaru dahulu, dan menghapus', () async {
      final notes = NotesStore(MemoryStore());
      expect(await notes.add('pertama', DateTime(2026, 1, 1)), isNull);
      expect(await notes.add('kedua', DateTime(2026, 1, 2)), isNull);
      expect(notes.list().map((n) => n.text), ['kedua', 'pertama']);
      await notes.remove(notes.list().first.id);
      expect(notes.list().length, 1);
    });

    test('menolak kosong, terlalu panjang, dan penuh', () async {
      final notes = NotesStore(MemoryStore());
      expect(await notes.add('   '), 'Catatan tidak boleh kosong.');
      expect(await notes.add('x' * (NotesStore.maxLength + 1)), contains('maksimal'));
      for (var i = 0; i < NotesStore.maxNotes; i++) {
        await notes.add('c$i', DateTime(2026, 1, 1, 0, 0, i));
      }
      expect(await notes.add('lebih'), contains('penuh'));
    });
  });

  group('SnapshotStore', () {
    test('simpan, muat, dan hapus semua (kunci lain aman)', () async {
      final store = MemoryStore();
      final snap = SnapshotStore(store);
      await store.setString('lain', 'tetap');
      await snap.save('stock', {'T001': []}, DateTime(2026, 5, 1));
      final loaded = snap.load('stock')!;
      expect(loaded.at, DateTime(2026, 5, 1));
      expect(loaded.data, {'T001': []});
      await snap.clearAll();
      expect(snap.load('stock'), isNull);
      expect(store.getString('lain'), 'tetap');
    });

    test('data rusak dianggap tidak ada', () {
      final store = MemoryStore()..setString('${SnapshotStore.prefix}stock', 'bukan json');
      expect(SnapshotStore(store).load('stock'), isNull);
    });
  });

  test('PreferencesStore: tema, cetak otomatis, dan pembatas login', () async {
    final prefs = PreferencesStore(MemoryStore());
    expect(prefs.theme, isNull);
    await prefs.setTheme('dark');
    expect(prefs.theme, 'dark');
    expect(prefs.autoPrint, isFalse);
    await prefs.setAutoPrint(true);
    expect(prefs.autoPrint, isTrue);
    await prefs.setThrottle(3, 12345);
    expect(prefs.throttle, (count: 3, lockedUntil: 12345));
    await prefs.resetThrottle();
    expect(prefs.throttle.count, 0);
  });
}
