import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../data/models/models.dart';
import '../data/repositories/return_repository.dart';
import 'sales_view_model.dart';
import 'session_view_model.dart';
import 'stock_view_model.dart';

const returnKinds = [
  (id: 'pelanggan', label: 'Dari Pelanggan', hint: 'Barang dikembalikan pembeli. Stok bertambah, uang dikembalikan.'),
  (id: 'supplier', label: 'Ke Supplier / Rusak', hint: 'Barang rusak atau kedaluwarsa keluar dari stok. Tidak ada uang.'),
];

const returnReasons = {
  'pelanggan': [Option('rusak', 'Barang rusak'), Option('salah_barang', 'Salah barang'), Option('tidak_sesuai', 'Tidak sesuai pesanan'), Option('lainnya', 'Lainnya')],
  'supplier': [Option('rusak', 'Barang rusak'), Option('kedaluwarsa', 'Kedaluwarsa'), Option('lainnya', 'Lainnya')],
};

const maxReturnNote = 100;

String reasonLabel(String id) {
  for (final list in returnReasons.values) {
    for (final o in list) {
      if (o.value == id) return o.label;
    }
  }
  return id;
}

/// Retur stok per tenant. Retur pelanggan dibatasi jumlah yang pernah terjual; retur dicatat HANYA
/// lewat fungsi database process_return().
class ReturnsViewModel extends ChangeNotifier {
  ReturnsViewModel(this._repo, this._session, this._stock, this._sales);

  final ReturnRepository _repo;
  final SessionViewModel _session;
  final StockViewModel _stock;
  final SalesViewModel _sales;

  Map<String, List<StockReturn>> _data = {};

  List<StockReturn> get items => List.unmodifiable(_data[_session.tenantId] ?? const []);

  void clear() {
    _data = {};
    notifyListeners();
  }

  Future<({bool success, String? error, bool expired})> load() async {
    final result = await _repo.fetchAll();
    switch (result) {
      case Err(:final error):
        return (success: false, error: describeError(error, forbidden: 'Tidak punya akses untuk retur ini.'), expired: error.expired);
      case Ok(:final data):
        _data = {for (final t in _session.tenants) t.id: <StockReturn>[], ...data};
        notifyListeners();
        return (success: true, error: null, expired: false);
    }
  }

  /// Jumlah per barang: yang pernah terjual dan yang sudah diretur pelanggan (tenant aktif).
  Map<String, ({int sold, int returned})> customerReturnLimits() {
    final sold = <String, int>{};
    final returned = <String, int>{};
    for (final sale in _sales.sales) {
      for (final line in sale.lines) {
        sold[line.id] = (sold[line.id] ?? 0) + line.qty;
      }
    }
    for (final ret in items) {
      if (ret.kind == 'pelanggan') returned[ret.itemId] = (returned[ret.itemId] ?? 0) + ret.qty;
    }
    return {for (final id in {...sold.keys, ...returned.keys}) id: (sold: sold[id] ?? 0, returned: returned[id] ?? 0)};
  }

  /// Mengembalikan (retur, error).
  Future<({StockReturn? ret, String? error})> process({required String kind, required String itemId, required int qty, required String reason, String? note}) async {
    final tenant = _session.tenantId;
    final result = await _repo.process(tenant: tenant, kind: kind, itemId: itemId, qty: qty, reason: reason, note: note);
    switch (result) {
      case Err(:final error):
        return (ret: null, error: describeError(error, forbidden: 'Tidak punya akses untuk retur ini.'));
      case Ok(:final data):
        _data = {..._data, tenant: [...(_data[tenant] ?? const []), data]};
        _stock.applyDelta(itemId, kind == 'pelanggan' ? qty : -qty);
        notifyListeners();
        return (ret: data, error: null);
    }
  }
}
