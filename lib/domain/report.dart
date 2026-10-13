import '../core/calendar.dart';
import '../core/format.dart';
import '../data/models/models.dart';

enum PeriodKind { harian, mingguan, bulanan }

const periodLabels = {PeriodKind.harian: 'Harian', PeriodKind.mingguan: 'Mingguan', PeriodKind.bulanan: 'Bulanan'};

DateRange periodRange(PeriodKind kind, DateTime anchor) {
  final day = startOfDay(anchor);
  switch (kind) {
    case PeriodKind.harian:
      return DateRange(day, addDays(day, 1));
    case PeriodKind.mingguan:
      final start = addDays(day, -mondayIndex(day));
      return DateRange(start, addDays(start, 7));
    case PeriodKind.bulanan:
      return DateRange(DateTime(day.year, day.month, 1), DateTime(day.year, day.month + 1, 1));
  }
}

/// Geser jangkar ke periode sebelumnya (delta -1) atau berikutnya (+1).
DateTime shiftAnchor(PeriodKind kind, DateTime anchor, int delta) {
  final day = startOfDay(anchor);
  switch (kind) {
    case PeriodKind.harian:
      return addDays(day, delta);
    case PeriodKind.mingguan:
      return addDays(day, 7 * delta);
    case PeriodKind.bulanan:
      return DateTime(day.year, day.month + delta, 1);
  }
}

String periodLabel(PeriodKind kind, DateRange range) {
  switch (kind) {
    case PeriodKind.harian:
      return formatDateWithWeekday(range.start);
    case PeriodKind.bulanan:
      return '${namaBulan[range.start.month - 1]} ${range.start.year}';
    case PeriodKind.mingguan:
      final first = range.start;
      final last = addDays(range.end, -1);
      if (first.year != last.year) return '${first.day} ${bulanPendek[first.month - 1]} ${first.year} – ${last.day} ${bulanPendek[last.month - 1]} ${last.year}';
      if (first.month != last.month) return '${first.day} ${bulanPendek[first.month - 1]} – ${last.day} ${bulanPendek[last.month - 1]} ${last.year}';
      return '${first.day}–${last.day} ${bulanPendek[last.month - 1]} ${last.year}';
  }
}

class Bucket {
  Bucket({required this.label, this.sub = ''});
  final String label;
  final String sub;
  int qty = 0;
  int revenue = 0;
  int trx = 0;
}

class ItemTotal {
  ItemTotal({required this.id, required this.name, required this.unit});
  final String id;
  String name;
  String unit;
  int qty = 0;
  int revenue = 0;
}

class SalesReport {
  SalesReport({required this.sales, required this.itemCount, required this.revenue, required this.items, required this.buckets});
  final List<Sale> sales;
  final int itemCount;
  final int revenue;
  final List<ItemTotal> items;
  final List<Bucket> buckets;

  int get trxCount => sales.length;
  int get kindCount => items.length;
  int get peakQty => buckets.fold(0, (m, b) => b.qty > m ? b.qty : m);
}

List<Bucket> _emptyBuckets(PeriodKind kind, DateRange range) {
  switch (kind) {
    case PeriodKind.harian:
      return List.generate(24, (h) => Bucket(label: '$h'));
    case PeriodKind.mingguan:
      return List.generate(7, (i) => Bucket(label: hariPendek[i], sub: '${addDays(range.start, i).day}'));
    case PeriodKind.bulanan:
      final days = DateTime(range.start.year, range.start.month + 1, 0).day;
      return List.generate(days, (i) => Bucket(label: '${i + 1}'));
  }
}

int _bucketIndex(PeriodKind kind, DateTime d) => switch (kind) {
      PeriodKind.harian => d.hour,
      PeriodKind.mingguan => mondayIndex(d),
      PeriodKind.bulanan => d.day - 1,
    };

/// Rangkuman penjualan dalam satu periode: barang keluar (terbanyak dahulu) dan batang grafik.
SalesReport aggregate(PeriodKind kind, DateRange range, List<Sale> sales) {
  final inRange = sales.where((s) => range.contains(s.at.toLocal())).toList()..sort((a, b) => b.at.compareTo(a.at));
  final buckets = _emptyBuckets(kind, range);
  final items = <String, ItemTotal>{};
  var itemCount = 0;
  var revenue = 0;

  for (final sale in inRange) {
    final bucket = buckets[_bucketIndex(kind, sale.at.toLocal())];
    var saleQty = 0;
    for (final line in sale.lines) {
      final entry = items.putIfAbsent(line.id, () => ItemTotal(id: line.id, name: line.name, unit: line.unit));
      entry.qty += line.qty;
      entry.revenue += line.qty * line.price;
      entry.name = line.name;
      entry.unit = line.unit;
      saleQty += line.qty;
    }
    bucket.trx += 1;
    bucket.qty += saleQty;
    bucket.revenue += sale.total;
    itemCount += saleQty;
    revenue += sale.total;
  }

  final ranked = items.values.toList()..sort((a, b) => b.qty != a.qty ? b.qty.compareTo(a.qty) : a.name.compareTo(b.name));
  return SalesReport(sales: inRange, itemCount: itemCount, revenue: revenue, items: ranked, buckets: buckets);
}
