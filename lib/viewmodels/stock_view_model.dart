import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../data/local/local_stores.dart';
import '../data/models/models.dart';
import '../data/repositories/stock_repository.dart';
import '../domain/stock_rules.dart';
import 'session_view_model.dart';

const _snapshotName = 'stock';

typedef StockLoad = ({bool success, bool offline, DateTime? at, String? error, bool expired});

/// Stok & harga per tenant. Di aplikasi hanya ada salinan yang dimuat saat dibuka; perubahan langsung
/// tampil lalu dikirim ke database secara berurutan. Bila ditolak (mis. nama ganda, tanpa akses),
/// perubahan dibatalkan dan daftar dimuat ulang. Penjualan tidak lewat sini: fungsi checkout() di
/// database yang mengurangi stok, lalu salinan ini disesuaikan lewat [applySale].
class StockViewModel extends ChangeNotifier {
  StockViewModel(this._repo, this._session, this._snapshots);

  final StockRepository _repo;
  final SessionViewModel _session;
  final SnapshotStore _snapshots;

  Map<String, List<StockItem>> _data = {};
  Future<void> _chain = Future.value();
  Timer? _snapshotTimer;
  final _errorHandlers = <void Function(String)>[];

  /// Dipanggil bila database menolak / tidak bisa menyimpan.
  void onSaveError(void Function(String message) handler) => _errorHandlers.add(handler);

  List<StockItem> get items => List.unmodifiable(_data[_session.tenantId] ?? const []);

  StockItem? findByBarcode(String code) {
    final text = code.trim();
    if (text.isEmpty) return null;
    for (final i in items) {
      if (i.barcode != null && sameBarcode(i.barcode, text)) return i;
    }
    return null;
  }

  void clear() {
    _snapshotTimer?.cancel();
    _data = {};
    notifyListeners();
  }

  void _commit(List<StockItem> next) {
    _data = {..._data, _session.tenantId: next};
    _scheduleSnapshot();
    notifyListeners();
  }

  /// Salinan offline ditulis paling cepat tiap 1 detik: meng-encode seluruh stok pada setiap
  /// ketukan (mis. tiap barang laku) membebani UI saat daftar barang besar.
  void _scheduleSnapshot() {
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer(const Duration(seconds: 1), _writeSnapshot);
  }

  void _writeSnapshot() {
    _snapshots.save(_snapshotName, _data.map((k, v) => MapEntry(k, v.map((i) => i.toJson()).toList()))); // agar aplikasi yang dibuka offline melihat stok terbaru
  }

  /// Muat stok dari database. Tanpa jaringan dan ada salinan terakhir di perangkat: salinan dipakai
  /// (offline=true) agar penjualan tetap bisa dicatat.
  Future<StockLoad> load() async {
    final result = await _repo.fetchAll();
    switch (result) {
      case Err(:final error):
        if (error.isNetwork) {
          final saved = _snapshots.load(_snapshotName);
          if (saved != null) {
            try {
              final raw = Map<String, dynamic>.from(saved.data as Map);
              _data = raw.map((k, v) => MapEntry(k, (v as List).map((e) => StockItem.fromJson(Map<String, dynamic>.from(e as Map))).toList()));
              notifyListeners();
              return (success: true, offline: true, at: saved.at, error: null, expired: false);
            } catch (_) {
              // salinan rusak: perlakukan seperti tidak ada
            }
          }
        }
        return (success: false, offline: false, at: null, error: describeStockError(error), expired: error.expired);
      case Ok(:final data):
        _data = {for (final t in _session.tenants) t.id: <StockItem>[], ...data};
        _writeSnapshot();
        notifyListeners();
        return (success: true, offline: false, at: null, error: null, expired: false);
    }
  }

  String describeStockError(AppError error) => describeError(error, byCode: const {'23505': 'Nama atau barcode sudah dipakai barang lain.'}, forbidden: 'Tidak punya akses untuk perubahan ini.');

  void _persist(Future<Result<void>> Function() send) {
    _chain = _chain.then((_) async {
      final result = await send();
      if (result case Err(:final error)) {
        final message = '${describeStockError(error)} Perubahan dibatalkan.';
        for (final handler in _errorHandlers) {
          handler(message);
        }
        await load();
      }
    });
  }

  String _newId() => 'stk_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${(DateTime.now().microsecond % 10000).toRadixString(36)}';

  /// Mengembalikan (item, error).
  ({StockItem? item, String? error}) add({required String name, required String qty, required String unit, String barcode = ''}) {
    final checked = validateStock(name: name, qty: qty, unit: unit, barcode: barcode, items: items);
    if (checked.error != null) return (item: null, error: checked.error);
    final v = checked.value!;
    final tenant = _session.tenantId;
    final item = StockItem(id: _newId(), name: v.name, qty: v.qty, unit: v.unit, barcode: v.barcode.isEmpty ? null : v.barcode);
    _commit([...items, item]);
    _persist(() => _repo.upsert(tenant, item));
    return (item: item, error: null);
  }

  ({StockItem? item, String? error}) update(String id, {required String name, required String qty, required String unit, String barcode = ''}) {
    final current = items;
    if (!current.any((i) => i.id == id)) return (item: null, error: 'Barang tidak ditemukan.');
    final checked = validateStock(name: name, qty: qty, unit: unit, barcode: barcode, items: current, ignoreId: id);
    if (checked.error != null) return (item: null, error: checked.error);
    final v = checked.value!;
    final tenant = _session.tenantId;
    final next = [
      for (final i in current)
        if (i.id == id) i.copyWith(name: v.name, qty: v.qty, unit: v.unit, barcode: v.barcode, clearBarcode: v.barcode.isEmpty) else i,
    ];
    _commit(next);
    final item = next.firstWhere((i) => i.id == id);
    _persist(() => _repo.upsert(tenant, item));
    return (item: item, error: null);
  }

  String? remove(String id) {
    final current = items;
    if (!current.any((i) => i.id == id)) return 'Barang tidak ditemukan.';
    final tenant = _session.tenantId;
    _commit(current.where((i) => i.id != id).toList());
    _persist(() => _repo.delete(tenant, id));
    return null;
  }

  /// Harga jual per barang (rupiah, bilangan bulat). Mengembalikan (item, error).
  ({StockItem? item, String? error}) setPrice(String id, String raw) {
    final current = items;
    if (!current.any((i) => i.id == id)) return (item: null, error: 'Barang tidak ditemukan.');
    final checked = validatePrice(raw);
    if (checked.error != null) return (item: null, error: checked.error);
    final price = checked.price!;
    final tenant = _session.tenantId;
    final next = [for (final i in current) if (i.id == id) i.copyWith(price: price) else i];
    _commit(next);
    _persist(() => _repo.setPrice(tenant, id, price));
    return (item: next.firstWhere((i) => i.id == id), error: null);
  }

  /// Sesuaikan salinan lokal setelah penjualan berhasil dicatat database (stok di database sudah dikurangi).
  void applySale(List<SaleLine> lines) {
    final sold = {for (final l in lines) l.id: l.qty};
    _commit([for (final i in items) if (sold.containsKey(i.id)) i.copyWith(qty: (i.qty - sold[i.id]!).clamp(0, 1 << 30)) else i]);
  }

  /// Sesuaikan salinan lokal setelah retur dicatat: delta + (retur pelanggan) atau - (supplier).
  void applyDelta(String id, int delta) {
    _commit([for (final i in items) if (i.id == id) i.copyWith(qty: (i.qty + delta).clamp(0, 1 << 30)) else i]);
  }
}
