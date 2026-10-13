import '../core/config.dart';
import '../data/models/models.dart';

/// Logika keranjang & pembayaran (murni). Keranjang adalah Map<idBarang, jumlah> yang tidak pernah
/// diubah langsung: setiap perubahan mengembalikan Map baru.
typedef Cart = Map<String, int>;

/// Menambah/mengurangi jumlah satu barang. Hasil dibatasi 0..stok; 0 = keluar dari keranjang.
Cart changeQty(Cart cart, StockItem item, int delta) {
  final next = Map<String, int>.of(cart);
  final qty = ((cart[item.id] ?? 0) + delta).clamp(0, item.qty);
  if (qty == 0) {
    next.remove(item.id);
  } else {
    next[item.id] = qty;
  }
  return next;
}

Cart removeLine(Cart cart, String id) => Map<String, int>.of(cart)..remove(id);

/// Baris keranjang dari data stok terkini. Barang yang dihapus / kehilangan harga / habis dibuang,
/// dan jumlah dipangkas ke stok yang tersisa.
List<CartLine> buildLines(List<StockItem> items, Cart cart) {
  final lines = <CartLine>[];
  for (final item in items) {
    final wanted = cart[item.id];
    if (wanted == null || !item.isSellable) continue;
    final qty = wanted < item.qty ? wanted : item.qty;
    lines.add(CartLine(id: item.id, name: item.name, unit: item.unit, price: item.price!, stock: item.qty, qty: qty));
  }
  return lines;
}

Cart sanitizeCart(List<StockItem> items, Cart cart) => {for (final l in buildLines(items, cart)) l.id: l.qty};

({int lineCount, int itemCount, int total}) summarize(List<CartLine> lines) => (
      lineCount: lines.length,
      itemCount: lines.fold(0, (s, l) => s + l.qty),
      total: lines.fold(0, (s, l) => s + l.subtotal),
    );

/// Usulan nominal uang tunai: uang pas + pembulatan ke atas ke pecahan umum (maks. 4 pilihan).
List<int> cashSuggestions(int total) {
  if (total <= 0) return const [];
  final rounded = [5000, 10000, 50000, 100000].map((step) => ((total + step - 1) ~/ step) * step);
  final unik = {total, ...rounded}.where((v) => v <= AppConfig.maxPayment).toList()..sort();
  return unik.take(4).toList();
}

/// Angka dari teks isian ("1.250.000" -> 1250000). Kosong/tidak valid -> null.
int? parseAmount(String? text) {
  final digits = (text ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  final value = int.tryParse(digits);
  return value;
}
