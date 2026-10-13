import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../data/models/models.dart';
import 'sales_view_model.dart';
import 'stock_view_model.dart';

enum StockFilter { semua, menipis, habis }

enum StockStatus { aman, menipis, habis }

StockStatus statusOf(int qty) => qty <= 0 ? StockStatus.habis : (qty <= AppConfig.lowStockMax ? StockStatus.menipis : StockStatus.aman);

/// Stok Total: sisa stok terakhir setelah semua transaksi, dengan pencarian dan filter status.
class StokTotalViewModel extends ChangeNotifier {
  StokTotalViewModel({required this.stock, required this.sales});
  final StockViewModel stock;
  final SalesViewModel sales;

  StockFilter filter = StockFilter.semua;
  String query = '';

  void setFilter(StockFilter value) {
    filter = value;
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  int get total => stock.items.length;
  int get low => stock.items.where((i) => statusOf(i.qty) == StockStatus.menipis).length;
  int get out => stock.items.where((i) => statusOf(i.qty) == StockStatus.habis).length;

  Map<String, int> get soldById {
    final sold = <String, int>{};
    for (final sale in sales.sales) {
      for (final line in sale.lines) {
        sold[line.id] = (sold[line.id] ?? 0) + line.qty;
      }
    }
    return sold;
  }

  List<StockItem> get visible {
    final needle = query.trim().toLowerCase();
    return stock.items.where((item) {
      final status = statusOf(item.qty);
      if (filter == StockFilter.menipis && status != StockStatus.menipis) return false;
      if (filter == StockFilter.habis && status != StockStatus.habis) return false;
      return needle.isEmpty || item.name.toLowerCase().contains(needle) || (item.barcode ?? '').toLowerCase().contains(needle);
    }).toList();
  }
}
