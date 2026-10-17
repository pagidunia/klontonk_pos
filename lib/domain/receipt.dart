import '../data/models/models.dart';

/// Struk penjualan (dari kasir). Jumlah per barang dihitung ulang dari qty x harga.
class Receipt {
  const Receipt({this.customerName, required this.no, required this.at, required this.cashier, required this.tenant, required this.lines, required this.total, required this.method, required this.paid, required this.change, required this.pending});
  final String no;
  final DateTime at;
  final String cashier;
  final String tenant;
  final List<SaleLine> lines;
  final int total;
  final String method;
  final int paid;
  final int change;
  final bool pending;

  int get itemCount => lines.fold(0, (s, l) => s + l.qty);
  bool get isCash => method == 'tunai';

  /// Nama pelanggan (hanya untuk penjualan utang).
  final String? customerName;

  bool get isDebt => method == 'utang';

  static const paymentLabel = {'nontunai': 'QRIS / Transfer', 'utang': 'Utang'};
}
