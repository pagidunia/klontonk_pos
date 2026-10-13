import 'package:flutter_test/flutter_test.dart';
import 'package:klontonk_pos/data/models/models.dart';
import 'package:klontonk_pos/domain/cart.dart';

StockItem item(String id, {int qty = 10, int? price = 5000}) => StockItem(id: id, name: 'Barang $id', qty: qty, unit: 'pcs', price: price);

void main() {
  group('changeQty', () {
    test('menambah dan membatasi sampai stok', () {
      final a = item('a', qty: 3);
      var cart = changeQty({}, a, 1);
      expect(cart, {'a': 1});
      cart = changeQty(cart, a, 5);
      expect(cart, {'a': 3});
    });

    test('jumlah 0 mengeluarkan barang dari keranjang', () {
      final a = item('a');
      final cart = changeQty({'a': 1}, a, -1);
      expect(cart.containsKey('a'), isFalse);
    });

    test('tidak mengubah keranjang asli', () {
      final original = <String, int>{'a': 1};
      changeQty(original, item('a'), 1);
      expect(original, {'a': 1});
    });
  });

  group('buildLines / sanitizeCart', () {
    test('membuang barang tanpa harga, habis, atau sudah dihapus; memangkas ke stok', () {
      final items = [item('a', qty: 2), item('b', price: null), item('c', qty: 0)];
      final lines = buildLines(items, {'a': 5, 'b': 1, 'c': 1, 'zzz': 1});
      expect(lines.map((l) => l.id), ['a']);
      expect(lines.single.qty, 2);
      expect(lines.single.subtotal, 10000);
    });

    test('summarize menjumlahkan jenis, barang, dan total', () {
      final lines = buildLines([item('a'), item('b', price: 2500)], {'a': 2, 'b': 4});
      final s = summarize(lines);
      expect((s.lineCount, s.itemCount, s.total), (2, 6, 20000));
    });
  });

  group('cashSuggestions', () {
    test('uang pas + pembulatan, maksimal 4 pilihan', () {
      expect(cashSuggestions(87500), [87500, 90000, 100000]);
      expect(cashSuggestions(0), isEmpty);
      expect(cashSuggestions(12345).length, lessThanOrEqualTo(4));
    });
  });

  test('parseAmount mengambil angka dari teks berformat', () {
    expect(parseAmount('1.250.000'), 1250000);
    expect(parseAmount(''), isNull);
    expect(parseAmount('abc'), isNull);
    expect(parseAmount(null), isNull);
  });
}
