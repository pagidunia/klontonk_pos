import 'package:flutter_test/flutter_test.dart';
import 'package:klontonk_pos/core/calendar.dart';
import 'package:klontonk_pos/data/models/models.dart';
import 'package:klontonk_pos/domain/finance.dart';
import 'package:klontonk_pos/domain/report.dart';

Sale sale(DateTime at, {String no = 'T', int total = 10000, String method = 'tunai', String cashier = 'Dewi', List<SaleLine>? lines}) =>
    Sale(no: no, at: at, cashier: cashier, method: method, total: total, paid: total, lines: lines ?? [SaleLine(id: 'a', name: 'Beras', unit: 'kg', qty: 2, price: total ~/ 2)]);

StockReturn ret(DateTime at, {String kind = 'pelanggan', int amount = 3000}) => StockReturn(no: 'R', at: at, cashier: 'k', kind: kind, itemId: 'a', name: 'Beras', unit: 'kg', qty: 1, amount: amount, reason: 'rusak');

void main() {
  // Rabu, 7 Oktober 2026
  final rabu = DateTime(2026, 10, 7, 14, 30);

  group('periodRange', () {
    test('mingguan dimulai Senin', () {
      final r = periodRange(PeriodKind.mingguan, rabu);
      expect(r.start, DateTime(2026, 10, 5));
      expect(r.end, DateTime(2026, 10, 12));
    });

    test('bulanan dan harian setengah-terbuka', () {
      expect(periodRange(PeriodKind.bulanan, rabu).end, DateTime(2026, 11, 1));
      expect(periodRange(PeriodKind.harian, rabu).contains(DateTime(2026, 10, 7, 23, 59)), isTrue);
      expect(periodRange(PeriodKind.harian, rabu).contains(DateTime(2026, 10, 8)), isFalse);
    });

    test('shiftAnchor melewati batas bulan', () {
      expect(shiftAnchor(PeriodKind.bulanan, DateTime(2026, 1, 15), -1), DateTime(2025, 12, 1));
      expect(shiftAnchor(PeriodKind.mingguan, rabu, 1), DateTime(2026, 10, 14));
    });
  });

  group('aggregate', () {
    test('menjumlahkan barang, omzet, dan batang per jam', () {
      final range = periodRange(PeriodKind.harian, rabu);
      final r = aggregate(PeriodKind.harian, range, [
        sale(DateTime(2026, 10, 7, 9), total: 10000),
        sale(DateTime(2026, 10, 7, 9, 45), total: 6000),
        sale(DateTime(2026, 10, 6, 9), total: 99999), // di luar periode
      ]);
      expect(r.trxCount, 2);
      expect(r.revenue, 16000);
      expect(r.itemCount, 4);
      expect(r.buckets[9].trx, 2);
      expect(r.items.single.qty, 4);
    });

    test('urutan barang: jumlah terbanyak dahulu', () {
      final range = periodRange(PeriodKind.harian, rabu);
      final r = aggregate(PeriodKind.harian, range, [
        sale(rabu, lines: const [SaleLine(id: 'a', name: 'A', unit: 'pcs', qty: 1, price: 1000), SaleLine(id: 'b', name: 'B', unit: 'pcs', qty: 5, price: 1000)], total: 6000),
      ]);
      expect(r.items.map((e) => e.id), ['b', 'a']);
    });
  });

  group('finance', () {
    test('financeRangeCustom menukar ujung dan inklusif', () {
      final r = financeRangeCustom(DateTime(2026, 10, 9), DateTime(2026, 10, 7));
      expect(r.start, DateTime(2026, 10, 7));
      expect(r.end, DateTime(2026, 10, 10));
    });

    test('ringkasan: omzet, refund hanya retur pelanggan, net, metode, kasir', () {
      final range = financeRange(FinanceMode.bulanan, rabu);
      final s = financeSummary(FinanceMode.bulanan, range, [
        sale(DateTime(2026, 10, 1, 10), total: 20000),
        sale(DateTime(2026, 10, 2, 10), total: 10000, method: 'nontunai', cashier: 'Budi'),
        sale(DateTime(2026, 9, 30, 10), total: 50000), // bulan lain
      ], [
        ret(DateTime(2026, 10, 3), amount: 4000),
        ret(DateTime(2026, 10, 3), kind: 'supplier', amount: 9999),
      ]);
      expect(s.omzet, 30000);
      expect(s.refund, 4000);
      expect(s.net, 26000);
      expect(s.trx, 2);
      expect(s.tunai, 20000);
      expect(s.nontunai, 10000);
      expect(s.cashiers.first.name, 'Dewi');
      expect(s.avg, 15000);
      expect(s.buckets.length, 31);
      expect(s.buckets[0].revenue, 20000);
    });

    test('tahunan memakai 12 batang bulan', () {
      final range = financeRange(FinanceMode.tahunan, rabu);
      final s = financeSummary(FinanceMode.tahunan, range, [sale(DateTime(2026, 3, 5), total: 7000)], const []);
      expect(s.buckets.length, 12);
      expect(s.buckets[2].revenue, 7000);
    });

    test('shiftFinanceAnchor', () {
      expect(shiftFinanceAnchor(FinanceMode.tahunan, rabu, -1), DateTime(2025, 1, 1));
      expect(shiftFinanceAnchor(FinanceMode.harian, rabu, 1), DateTime(2026, 10, 8));
    });
  });

  test('calendar helpers', () {
    expect(isSameDay(DateTime(2026, 1, 1, 1), DateTime(2026, 1, 1, 23)), isTrue);
    expect(mondayIndex(DateTime(2026, 10, 4)), 6); // Minggu
  });
}
