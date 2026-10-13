import 'package:flutter/foundation.dart';

import '../core/calendar.dart';
import '../domain/finance.dart';
import 'returns_view_model.dart';
import 'sales_view_model.dart';

/// Laporan Keuangan: omzet, retur pelanggan, arus kas bersih; harian/bulanan/tahunan atau rentang bebas.
class KeuanganViewModel extends ChangeNotifier {
  KeuanganViewModel({required this.sales, required this.returns, DateTime? now}) : anchor = now ?? DateTime.now() {
    customStart = startOfDay(anchor);
    customEnd = startOfDay(anchor);
  }
  final SalesViewModel sales;
  final ReturnsViewModel returns;

  FinanceMode mode = FinanceMode.harian;
  DateTime anchor;
  late DateTime customStart;
  late DateTime customEnd;

  DateRange get range => mode == FinanceMode.custom ? financeRangeCustom(customStart, customEnd) : financeRange(mode, anchor);
  String get label => financeRangeLabel(mode, range);
  bool get isCurrent => mode != FinanceMode.custom && isSameDay(financeRange(mode, DateTime.now()).start, range.start);

  FinanceSummary get summary => financeSummary(mode, range, sales.sales, returns.items);

  void setMode(FinanceMode value) {
    mode = value;
    if (value != FinanceMode.custom) anchor = DateTime.now();
    notifyListeners();
  }

  void shift(int delta) {
    anchor = shiftFinanceAnchor(mode, anchor, delta);
    notifyListeners();
  }

  void today() {
    anchor = DateTime.now();
    notifyListeners();
  }

  void setCustom(DateTime start, DateTime end) {
    customStart = startOfDay(start);
    customEnd = startOfDay(end);
    mode = FinanceMode.custom;
    notifyListeners();
  }
}
