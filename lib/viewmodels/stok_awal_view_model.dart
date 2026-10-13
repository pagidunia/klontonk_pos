import 'package:flutter/foundation.dart';

import '../data/models/models.dart';
import '../domain/csv_import.dart';
import '../services/services.dart';
import 'stock_view_model.dart';

/// Stok Awal: daftar barang tenant + form tambah/ubah. Hanya akun tenant (bukan admin) yang boleh mengubah.
class StokAwalViewModel extends ChangeNotifier {
  StokAwalViewModel({required this.stock, required this.dialog, required this.toast});

  final StockViewModel stock;
  final DialogService dialog;
  final ToastService toast;

  String? editingId;

  List<StockItem> get items => stock.items;
  StockItem? get editing => editingId == null ? null : items.where((i) => i.id == editingId).firstOrNull;

  void startEdit(StockItem? item) {
    editingId = item?.id;
    notifyListeners();
  }

  /// Simpan (tambah bila tidak sedang mengedit). Mengembalikan pesan galat atau null.
  String? save({required String name, required String qty, required String unit, required String barcode}) {
    final id = editingId;
    final result = id == null ? stock.add(name: name, qty: qty, unit: unit, barcode: barcode) : stock.update(id, name: name, qty: qty, unit: unit, barcode: barcode);
    if (result.error != null) return result.error;
    toast.show(id == null ? 'Barang ditambahkan.' : 'Perubahan disimpan.', type: ToastType.success);
    editingId = null;
    notifyListeners();
    return null;
  }

  Future<void> delete(StockItem item) async {
    final yakin = await dialog.confirm(title: 'Hapus Barang', message: 'Hapus "${item.name}" dari stok? Tindakan ini tidak bisa dibatalkan.', confirmText: 'Ya, Hapus', cancelText: 'Batal', danger: true);
    if (!yakin) return;
    stock.remove(item.id);
    if (editingId == item.id) editingId = null;
    toast.show('Barang dihapus.', type: ToastType.success);
    notifyListeners();
  }

  /// Impor stok dari teks CSV. Setiap barang tetap divalidasi; yang ditolak dilewati dan dilaporkan.
  Future<void> importCsv(String fileName, String text) async {
    final parsed = stockRowsFromCsv(text);
    String ringkas(Iterable<({int line, String message})> e) {
      final list = e.toList();
      final tampil = list.take(3).map((x) => 'baris ${x.line}: ${x.message}').join('; ');
      return list.length > 3 ? '$tampil; dan ${list.length - 3} lainnya' : tampil;
    }

    final galat = parsed.errors.map((e) => (line: e.line, message: e.message));
    if (parsed.rows.isEmpty) {
      await dialog.notify(title: 'Impor Stok', message: 'Tidak ada barang yang bisa diimpor dari "$fileName". ${ringkas(galat)}');
      return;
    }
    final lewat = parsed.errors.isEmpty ? '' : ' ${parsed.errors.length} baris bermasalah akan dilewati (${ringkas(galat)}).';
    final yakin = await dialog.confirm(
      title: 'Impor Stok dari CSV',
      message: '${parsed.rows.length} barang dari "$fileName" siap ditambahkan ke stok. Barang dengan nama yang sudah ada dilewati.$lewat',
      confirmText: 'Impor ${parsed.rows.length} barang',
      cancelText: 'Batal',
    );
    if (!yakin) return;

    final gagal = <({int line, String message})>[];
    var masuk = 0;
    for (var i = 0; i < parsed.rows.length; i++) {
      final row = parsed.rows[i];
      final r = stock.add(name: row.name, qty: row.qty, unit: row.unit, barcode: row.barcode ?? '');
      if (r.error != null) {
        gagal.add((line: i + 2, message: '"${row.name}": ${r.error}'));
        continue;
      }
      masuk++;
      if (row.price != null) stock.setPrice(r.item!.id, '${row.price}');
    }
    notifyListeners();
    if (gagal.isEmpty) {
      toast.show('$masuk barang berhasil diimpor.', type: ToastType.success);
    } else {
      await dialog.notify(title: 'Impor Selesai', message: '$masuk barang masuk, ${gagal.length} dilewati. ${ringkas(gagal)}');
    }
  }
}
