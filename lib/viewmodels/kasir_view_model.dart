import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../data/models/models.dart';
import '../domain/cart.dart';
import '../domain/receipt.dart';
import '../services/services.dart';
import 'sales_view_model.dart';
import 'session_view_model.dart';
import 'stock_view_model.dart';

/// Layar kasir: pilih barang (cari / scan), atur keranjang, terima pembayaran.
class KasirViewModel extends ChangeNotifier {
  KasirViewModel({required this.stock, required this.sales, required this.session, required this.toast}) {
    stock.addListener(_onStock);
  }

  final StockViewModel stock;
  final SalesViewModel sales;
  final SessionViewModel session;
  final ToastService toast;

  Cart _cart = {};
  String query = '';
  String method = 'tunai'; // 'tunai' | 'nontunai'
  String cashText = '';
  bool paying = false;
  Receipt? receipt;

  void _onStock() {
    _cart = sanitizeCart(stock.items, _cart);
    notifyListeners();
  }

  Cart get cart => _cart;

  /// Barang yang cocok dengan pencarian: yang bisa dijual lebih dulu, lalu urut nama.
  List<StockItem> get visible {
    final needle = query.toLowerCase();
    final list = stock.items.where((i) => needle.isEmpty || i.name.toLowerCase().contains(needle) || (i.barcode ?? '').toLowerCase().contains(needle)).toList()
      ..sort((a, b) {
        final s = (b.isSellable ? 1 : 0) - (a.isSellable ? 1 : 0);
        return s != 0 ? s : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  int get itemCountAll => stock.items.length;
  int get sellableCount => stock.items.where((i) => i.isSellable).length;

  List<CartLine> get lines => buildLines(stock.items, _cart);
  ({int lineCount, int itemCount, int total}) get summary => summarize(lines);

  void setQuery(String value) {
    query = value.trim();
    notifyListeners();
  }

  /// Tambah satu barang ke keranjang. Mengembalikan pesan bila stok tidak cukup.
  String? addItem(StockItem item) {
    final before = _cart[item.id] ?? 0;
    final next = changeQty(_cart, item, 1);
    if ((next[item.id] ?? 0) == before) return 'Stok "${item.name}" tinggal ${item.qty} ${item.unit}';
    _cart = next;
    notifyListeners();
    return null;
  }

  void changeLine(String id, int delta) {
    final item = stock.items.where((i) => i.id == id);
    if (item.isEmpty) return;
    _cart = changeQty(_cart, item.first, delta);
    notifyListeners();
  }

  void removeItem(String id) {
    _cart = removeLine(_cart, id);
    notifyListeners();
  }

  void clearCart() {
    _cart = {};
    cashText = '';
    notifyListeners();
  }

  void setMethod(String value) {
    method = value;
    notifyListeners();
  }

  void setCash(String text) {
    final amount = parseAmount(text);
    cashText = amount == null ? '' : _grouped(amount);
    notifyListeners();
  }

  void pickCash(int amount) => setCash('$amount');

  static String _grouped(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
      out.write(s[i]);
    }
    return out.toString();
  }

  /// Status pembayaran saat ini.
  ({int total, int? paid, bool canPay, String hint}) get payState {
    final total = summary.total;
    if (method != 'tunai') return (total: total, paid: total, canPay: total > 0, hint: '');
    final paid = parseAmount(cashText);
    final canPay = paid != null && paid >= total && paid <= AppConfig.maxPayment && total > 0;
    final hint = paid == null ? 'Masukkan uang diterima' : (paid > AppConfig.maxPayment ? 'Nominal terlalu besar' : 'Uang belum cukup');
    return (total: total, paid: paid, canPay: canPay, hint: hint);
  }

  /// Proses pembayaran. Mengembalikan pesan galat, atau null bila berhasil (struk tersedia di [receipt]).
  Future<String?> pay() async {
    if (paying) return null; // cegah tekan ganda selama menunggu database
    final current = lines;
    final state = payState;
    if (current.isEmpty || !state.canPay) return null;

    paying = true;
    notifyListeners();
    final result = await sales.checkout(method: method, paid: state.paid!, lines: current);
    paying = false;

    switch (result) {
      case CheckoutFail(:final error):
        await stock.load(); // stok bisa berubah di perangkat lain; samakan lalu sesuaikan keranjang
        notifyListeners();
        return error;
      case CheckoutOk(:final sale, :final offline):
        receipt = Receipt(
          no: sale.no,
          at: sale.at,
          cashier: sale.cashier,
          tenant: session.currentTenant.name,
          lines: sale.lines,
          total: sale.total,
          method: sale.method,
          paid: sale.paid,
          change: sale.method == 'tunai' ? sale.paid - sale.total : 0,
          pending: offline || sale.pending,
        );
        _cart = {};
        cashText = '';
        notifyListeners();
        return null;
    }
  }

  void closeReceipt() {
    receipt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stock.removeListener(_onStock);
    super.dispose();
  }
}
