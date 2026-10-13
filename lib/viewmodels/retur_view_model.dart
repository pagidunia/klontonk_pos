import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../data/models/models.dart';
import '../services/services.dart';
import 'returns_view_model.dart';
import 'stock_view_model.dart';

/// Stok Retur: retur dari pelanggan (stok bertambah, uang kembali) atau ke supplier / rusak (stok berkurang).
class ReturViewModel extends ChangeNotifier {
  ReturViewModel({required this.returns, required this.stock, required this.toast});
  final ReturnsViewModel returns;
  final StockViewModel stock;
  final ToastService toast;

  String kind = 'pelanggan';
  bool busy = false;

  String get hint => returnKinds.firstWhere((k) => k.id == kind).hint;
  List<Option> get reasons => returnReasons[kind]!;

  void setKind(String value) {
    kind = value;
    notifyListeners();
  }

  /// Daftar barang beserta alasan boleh/tidaknya diretur untuk jenis saat ini.
  List<({StockItem item, bool usable, String detail})> options() {
    final limits = returns.customerReturnLimits();
    return [
      for (final item in stock.items)
        if (kind == 'pelanggan') _customer(item, limits[item.id]) else _supplier(item),
    ];
  }

  ({StockItem item, bool usable, String detail}) _customer(StockItem item, ({int sold, int returned})? limit) {
    final sold = limit?.sold ?? 0;
    final left = sold - (limit?.returned ?? 0);
    final usable = left > 0 && item.price != null;
    final detail = item.price == null ? 'harga belum diisi' : (left > 0 ? 'bisa diretur $left ${item.unit}' : (sold > 0 ? 'sudah diretur semua' : 'belum pernah terjual'));
    return (item: item, usable: usable, detail: detail);
  }

  ({StockItem item, bool usable, String detail}) _supplier(StockItem item) =>
      (item: item, usable: item.qty > 0, detail: item.qty > 0 ? 'stok ${item.qty} ${item.unit}' : 'stok kosong');

  List<StockReturn> get history => returns.items.reversed.take(20).toList();

  ({int customerCount, int supplierCount, int refund}) get monthStats {
    final now = DateTime.now();
    final inMonth = returns.items.where((r) => r.at.toLocal().year == now.year && r.at.toLocal().month == now.month).toList();
    final customer = inMonth.where((r) => r.kind == 'pelanggan');
    return (customerCount: customer.length, supplierCount: inMonth.where((r) => r.kind == 'supplier').length, refund: customer.fold(0, (s, r) => s + r.amount));
  }

  /// Proses retur. Mengembalikan pesan galat atau null.
  Future<String?> submit({required String? itemId, required String qtyText, required String reason, required String note}) async {
    if (busy) return null;
    if (itemId == null || itemId.isEmpty) return 'Pilih barang dulu.';
    final qty = int.tryParse(qtyText.trim());
    if (qty == null || qty < 1 || qty > AppConfig.maxQty) return 'Jumlah harus bilangan bulat 1 – 1.000.000.';
    if (note.trim().length > maxReturnNote) return 'Catatan maksimal $maxReturnNote karakter.';

    busy = true;
    notifyListeners();
    final result = await returns.process(kind: kind, itemId: itemId, qty: qty, reason: reason, note: note.trim());
    busy = false;
    notifyListeners();
    if (result.error != null) return result.error;
    toast.show('Retur diproses.', type: ToastType.success);
    return null;
  }
}
