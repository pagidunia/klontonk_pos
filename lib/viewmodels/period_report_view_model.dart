import 'package:flutter/foundation.dart';

import '../core/calendar.dart';
import '../data/models/models.dart';
import '../domain/report.dart';
import 'returns_view_model.dart';
import 'sales_view_model.dart';

/// Periode laporan (harian / mingguan / bulanan) dengan navigasi maju-mundur. Dipakai halaman
/// Stok Keluar dan laporan Stok Keluar / Stok Retur.
class PeriodReportViewModel extends ChangeNotifier {
  PeriodReportViewModel({required this.sales, required this.returns, DateTime? now}) : anchor = now ?? DateTime.now();
  final SalesViewModel sales;
  final ReturnsViewModel returns;

  PeriodKind kind = PeriodKind.harian;
  DateTime anchor;
  bool showAllTrx = false;

  DateRange get range => periodRange(kind, anchor);
  bool get isCurrent => isSameDay(periodRange(kind, DateTime.now()).start, range.start);
  String get label => periodLabel(kind, range);

  SalesReport get salesReport => aggregate(kind, range, sales.sales);

  /// Retur dalam periode terpilih (terbaru lebih dulu).
  List<StockReturn> get returnsInRange => returns.items.where((r) => range.contains(r.at.toLocal())).toList()..sort((a, b) => b.at.compareTo(a.at));

  void setKind(PeriodKind value) {
    kind = value;
    anchor = DateTime.now();
    showAllTrx = false;
    notifyListeners();
  }

  void shift(int delta) {
    anchor = shiftAnchor(kind, anchor, delta);
    showAllTrx = false;
    notifyListeners();
  }

  void today() {
    anchor = DateTime.now();
    notifyListeners();
  }

  void toggleShowAll() {
    showAllTrx = !showAllTrx;
    notifyListeners();
  }
}
