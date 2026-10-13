import 'package:flutter_test/flutter_test.dart';
import 'package:klontonk_pos/core/result.dart';
import 'package:klontonk_pos/data/local/key_value_store.dart';
import 'package:klontonk_pos/data/local/local_stores.dart';
import 'package:klontonk_pos/data/models/models.dart';
import 'package:klontonk_pos/domain/outbox_logic.dart';
import 'package:klontonk_pos/domain/sync.dart';

const lines = [SaleLine(id: 'a', name: 'Beras', unit: 'kg', qty: 2, price: 15000)];

OutboxEntry entry(String id, {String user = 'u1'}) => buildEntry(clientId: id, tenant: 'T001', userId: user, cashier: 'Dewi', method: 'tunai', paid: 50000, lines: lines).entry!;

Sale sale() => Sale(no: 'TRX-1', at: DateTime(2026, 10, 12), cashier: 'Dewi', method: 'tunai', total: 30000, paid: 50000, lines: lines);

void main() {
  group('buildEntry', () {
    test('tunai: paid dipakai, total dihitung dari baris', () {
      final built = buildEntry(clientId: 'x', tenant: 'T001', userId: 'u', cashier: 'k', method: 'tunai', paid: 50000, lines: lines);
      expect(built.error, isNull);
      expect(built.entry!.expectedTotal, 30000);
      expect(built.entry!.paid, 50000);
    });

    test('nontunai: paid = total', () {
      final built = buildEntry(clientId: 'x', tenant: 'T001', userId: 'u', cashier: 'k', method: 'nontunai', paid: null, lines: lines);
      expect(built.entry!.paid, 30000);
    });

    test('menolak metode salah, keranjang kosong, uang kurang', () {
      expect(buildEntry(clientId: 'x', tenant: 't', userId: 'u', cashier: 'k', method: 'kartu', paid: 1, lines: lines).error, isNotNull);
      expect(buildEntry(clientId: 'x', tenant: 't', userId: 'u', cashier: 'k', method: 'tunai', paid: 1, lines: const []).error, 'Keranjang kosong.');
      expect(buildEntry(clientId: 'x', tenant: 't', userId: 'u', cashier: 'k', method: 'tunai', paid: 100, lines: lines).error, 'Uang diterima kurang dari total.');
    });
  });

  group('OutboxStore', () {
    test('menyimpan, tidak menggandakan client_id, dan menghapus', () async {
      final box = OutboxStore(MemoryStore());
      expect((await box.add(entry('1'))).ok, isTrue);
      expect((await box.add(entry('1'))).ok, isTrue);
      expect(box.count(), 1);
      await box.remove('1');
      expect(box.count(), 0);
    });

    test('menolak bila antrean penuh', () async {
      final box = OutboxStore(MemoryStore());
      for (var i = 0; i < OutboxStore.maxPending; i++) {
        await box.add(entry('id$i'));
      }
      final r = await box.add(entry('lebih'));
      expect(r.ok, isFalse);
    });

    test('data rusak dianggap kosong', () {
      final store = MemoryStore()..setString(OutboxStore.key, '{bukan json');
      expect(OutboxStore(store).list(), isEmpty);
    });
  });

  group('flushOutbox', () {
    late OutboxStore box;

    setUp(() async {
      box = OutboxStore(MemoryStore());
      await box.add(entry('1'));
      await box.add(entry('2'));
      await box.add(entry('3', user: 'orang-lain'));
    });

    test('mengirim berurutan milik user yang login saja', () async {
      final sent = <String>[];
      final s = await flushOutbox(outbox: box, userId: 'u1', send: (e) async {
        sent.add(e.clientId);
        return Ok(sale());
      });
      expect(sent, ['1', '2']);
      expect(s.synced.length, 2);
      expect(box.count(), 1); // milik user lain tetap
      expect(s.remaining, 0);
    });

    test('jaringan putus: berhenti dan entri tetap pending', () async {
      final s = await flushOutbox(outbox: box, userId: 'u1', send: (e) async => Err(AppError.network()));
      expect(s.stopped, 'network');
      expect(box.list().where((e) => e.userId == 'u1').every((e) => e.isPending), isTrue);
      expect(s.remaining, 2);
    });

    test('sesi berakhir: berhenti', () async {
      final s = await flushOutbox(outbox: box, userId: 'u1', send: (e) async => const Err(AppError(status: 401, message: 'jwt', expired: true)));
      expect(s.stopped, 'expired');
    });

    test('ditolak server: ditandai failed dan lanjut ke entri berikutnya', () async {
      var n = 0;
      final s = await flushOutbox(outbox: box, userId: 'u1', send: (e) async => n++ == 0 ? const Err(AppError(status: 400, message: 'harga kosong')) : Ok(sale()));
      expect(s.failed.single.error, 'harga kosong');
      expect(s.synced.length, 1);
      expect(box.list().firstWhere((e) => e.clientId == '1').isFailed, isTrue);
    });

    test('skema belum diperbarui: berhenti tanpa menandai gagal', () async {
      final s = await flushOutbox(outbox: box, userId: 'u1', send: (e) async => const Err(AppError(status: 404, code: schemaMissing, message: 'x')));
      expect(s.stopped, 'schema');
      expect(box.count('failed'), 0);
    });

    test('offline: tidak mengirim apa pun', () async {
      final s = await flushOutbox(outbox: box, userId: 'u1', isOnline: () => false, send: (e) async => Ok(sale()));
      expect(s.stopped, 'offline');
      expect(s.synced, isEmpty);
    });
  });
}
