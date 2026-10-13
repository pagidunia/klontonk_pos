import '../core/config.dart';
import '../data/models/models.dart';

const units = ['pcs', 'kg', 'liter', 'pak', 'bungkus', 'dus', 'karung', 'renceng'];

final _namePattern = RegExp(r"^[\p{L}\p{N} .,'()&/+-]{2,60}$", unicode: true);
final _barcodePattern = RegExp(r'^[A-Za-z0-9._-]{4,40}$');

bool sameBarcode(String? a, String? b) => (a ?? '').toLowerCase() == (b ?? '').toLowerCase();

class ValidStock {
  const ValidStock({required this.name, required this.qty, required this.unit, required this.barcode});
  final String name;
  final int qty;
  final String unit;
  final String barcode;
}

/// Validasi masukan stok (untuk tampilan; batasan yang sama diulang oleh database).
/// Mengembalikan (value, error): salah satunya null.
({ValidStock? value, String? error}) validateStock({required String name, required String qty, required String unit, required String barcode, required List<StockItem> items, String? ignoreId}) {
  final nama = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  final rawQty = qty.trim();
  if (nama.isEmpty) return (value: null, error: 'Nama barang wajib diisi.');
  if (!_namePattern.hasMatch(nama)) return (value: null, error: 'Nama barang 2–60 karakter (huruf, angka, spasi, dan tanda baca umum).');
  if (rawQty.isEmpty) return (value: null, error: 'Jumlah stok wajib diisi.');

  final jumlah = int.tryParse(rawQty);
  if (jumlah == null || jumlah < 0 || jumlah > AppConfig.maxQty) return (value: null, error: 'Jumlah harus bilangan bulat 0 – 1.000.000.');
  if (!units.contains(unit)) return (value: null, error: 'Satuan tidak valid.');

  if (items.any((i) => i.id != ignoreId && i.name.toLowerCase() == nama.toLowerCase())) return (value: null, error: 'Barang dengan nama itu sudah ada.');

  final kode = barcode.trim();
  if (kode.isNotEmpty && !_barcodePattern.hasMatch(kode)) return (value: null, error: 'Barcode 4–40 karakter (huruf, angka, titik, minus, underscore).');
  if (kode.isNotEmpty) {
    for (final i in items) {
      if (i.id != ignoreId && i.barcode != null && sameBarcode(i.barcode, kode)) return (value: null, error: 'Barcode sudah dipakai oleh "${i.name}".');
    }
  }
  return (value: ValidStock(name: nama, qty: jumlah, unit: unit, barcode: kode), error: null);
}

/// Harga jual per barang (rupiah, bilangan bulat). Mengembalikan (harga, error).
({int? price, String? error}) validatePrice(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return (price: null, error: 'Harga wajib diisi.');
  final harga = int.tryParse(text);
  if (harga == null || harga < 1 || harga > AppConfig.maxPrice) return (price: null, error: 'Harga harus bilangan bulat Rp 1 – Rp 100.000.000.');
  return (price: harga, error: null);
}
