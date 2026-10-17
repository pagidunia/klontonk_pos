import '../core/calendar.dart';
import '../core/format.dart';
import '../data/models/models.dart';

enum FinanceMode { harian, bulanan, tahunan, custom }

const financeLabels = {FinanceMode.harian: 'Harian', FinanceMode.bulanan: 'Bulanan', FinanceMode.tahunan: 'Tahunan'};

DateRange financeRange(FinanceMode mode, DateTime anchor) {
  final day = startOfDay(anchor);
  switch (mode) {
    case FinanceMode.harian:
      return DateRange(day, addDays(day, 1));
    case FinanceMode.bulanan:
      return DateRange(DateTime(day.year, day.month, 1), DateTime(day.year, day.month + 1, 1));
    case FinanceMode.tahunan:
      return DateRange(DateTime(day.year, 1, 1), DateTime(day.year + 1, 1, 1));
    case FinanceMode.custom:
      throw ArgumentError('Gunakan financeRangeCustom untuk rentang bebas.');
  }
}

/// Rentang bebas dari dua tanggal pilihan (kedua ujung inklusif). Bila mulai > akhir, ditukar.
DateRange financeRangeCustom(DateTime a, DateTime b) {
  final x = startOfDay(a);
  final y = startOfDay(b);
  final start = x.isAfter(y) ? y : x;
  final end = x.isAfter(y) ? x : y;
  return DateRange(start, addDays(end, 1));
}

DateTime shiftFinanceAnchor(FinanceMode mode, DateTime anchor, int delta) {
  final day = startOfDay(anchor);
  switch (mode) {
    case FinanceMode.harian:
      return addDays(day, delta);
    case FinanceMode.bulanan:
      return DateTime(day.year, day.month + delta, 1);
    case FinanceMode.tahunan:
      return DateTime(day.year + delta, 1, 1);
    case FinanceMode.custom:
      return day;
  }
}

String financeRangeLabel(FinanceMode mode, DateRange range) {
  switch (mode) {
    case FinanceMode.harian:
      return '${namaHari[mondayIndex(range.start)]}, ${formatDateLong(range.start)}';
    case FinanceMode.bulanan:
      return '${namaBulan[range.start.month - 1]} ${range.start.year}';
    case FinanceMode.tahunan:
      return '${range.start.year}';
    case FinanceMode.custom:
      final last = addDays(range.end, -1);
      return '${range.start.day} ${bulanPendek[range.start.month - 1]} ${range.start.year} – ${last.day} ${bulanPendek[last.month - 1]} ${last.year}';
  }
}

class FinanceBucket {
  FinanceBucket({required this.label, this.sub = ''});
  final String label;
  final String sub;
  int revenue = 0;
}

class CashierTotal {
  CashierTotal(this.name);
  final String name;
  int revenue = 0;
  int trx = 0;
}

class ItemRevenue {
  ItemRevenue({required this.id, required this.name, required this.unit});
  final String id;
  String name;
  String unit;
  int qty = 0;
  int revenue = 0;
}

class FinanceSummary {
  FinanceSummary({
    required this.omzet,
    required this.refund,
    required this.trx,
    required this.tunai,
    required this.nontunai,
    required this.utang,
    required this.cashiers,
    required this.items,
    required this.buckets,
    required this.sales,
  });

  final int omzet;
  final int refund;
  final int trx;
  final int tunai;
  final int nontunai;
  final int utang;
  final List<CashierTotal> cashiers;
  final List<ItemRevenue> items;
  final List<FinanceBucket> buckets;
  final List<Sale> sales;

  int get net => omzet - refund;
  double get avg => trx == 0 ? 0 : omzet / trx;
  int get peak => buckets.fold(0, (m, b) => b.revenue > m ? b.revenue : m);
}

List<FinanceBucket> financeBuckets(FinanceMode mode, DateRange range) {
  switch (mode) {
    case FinanceMode.harian:
      return List.generate(24, (h) => FinanceBucket(label: '$h'));
    case FinanceMode.bulanan:
      final days = DateTime(range.start.year, range.start.month + 1, 0).day;
      return List.generate(days, (i) => FinanceBucket(label: '${i + 1}'));
    case FinanceMode.tahunan:
      return List.generate(12, (i) => FinanceBucket(label: bulanPendek[i]));
    case FinanceMode.custom:
      final days = range.end.difference(range.start).inDays.clamp(1, 100000);
      return List.generate(days, (i) {
        final d = addDays(range.start, i);
        return FinanceBucket(label: '${d.day}', sub: bulanPendek[d.month - 1]);
      });
  }
}

int _index(FinanceMode mode, DateTime d, DateRange range) => switch (mode) {
      FinanceMode.harian => d.hour,
      FinanceMode.bulanan => d.day - 1,
      FinanceMode.tahunan => d.month - 1,
      FinanceMode.custom => startOfDay(d).difference(startOfDay(range.start)).inDays,
    };

/// Ringkasan keuangan satu rentang: omzet, retur pelanggan, arus kas bersih, per kasir, per barang, grafik.
FinanceSummary financeSummary(FinanceMode mode, DateRange range, List<Sale> sales, List<StockReturn> returns) {
  final salesIn = sales.where((s) => range.contains(s.at.toLocal())).toList()..sort((a, b) => b.at.compareTo(a.at));
  final refund = returns.where((r) => r.kind == 'pelanggan' && range.contains(r.at.toLocal())).fold(0, (s, r) => s + r.amount);

  var omzet = 0;
  var tunai = 0;
  var nontunai = 0;
  var utang = 0;
  final cashiers = <String, CashierTotal>{};
  final items = <String, ItemRevenue>{};
  final buckets = financeBuckets(mode, range);

  for (final sale in salesIn) {
    omzet += sale.total;
    if (sale.method == 'tunai') {
      tunai += sale.total;
    } else if (sale.method == 'utang') {
      utang += sale.total;
    } else {
      nontunai += sale.total;
    }
    final kasir = cashiers.putIfAbsent(sale.cashier, () => CashierTotal(sale.cashier));
    kasir.revenue += sale.total;
    kasir.trx += 1;

    for (final line in sale.lines) {
      final entry = items.putIfAbsent(line.id, () => ItemRevenue(id: line.id, name: line.name, unit: line.unit));
      entry.qty += line.qty;
      entry.revenue += line.qty * line.price;
      entry.name = line.name;
      entry.unit = line.unit;
    }

    final i = _index(mode, sale.at.toLocal(), range);
    if (i >= 0 && i < buckets.length) buckets[i].revenue += sale.total;
  }

  return FinanceSummary(
    omzet: omzet,
    refund: refund,
    trx: salesIn.length,
    tunai: tunai,
    nontunai: nontunai,
    utang: utang,
    cashiers: cashiers.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue)),
    items: items.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue)),
    buckets: buckets,
    sales: salesIn,
  );
}
