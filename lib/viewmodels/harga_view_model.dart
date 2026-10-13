import 'package:flutter/foundation.dart';

import '../data/models/models.dart';
import '../services/services.dart';
import 'stock_view_model.dart';

/// Update Harga: isi atau ubah harga jual tiap barang (hanya akun tenant).
class HargaViewModel extends ChangeNotifier {
  HargaViewModel({required this.stock, required this.toast});
  final StockViewModel stock;
  final ToastService toast;

  String? editingId;

  List<StockItem> get items => stock.items;
  int get pricedCount => items.where((i) => i.hasPrice).length;

  void startEdit(String? id) {
    editingId = id;
    notifyListeners();
  }

  /// Simpan harga. Mengembalikan pesan galat atau null.
  String? save(String id, String raw) {
    final result = stock.setPrice(id, raw);
    if (result.error != null) return result.error;
    toast.show('Harga "${result.item!.name}" disimpan.', type: ToastType.success);
    editingId = null;
    notifyListeners();
    return null;
  }
}
