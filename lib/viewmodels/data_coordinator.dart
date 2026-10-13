import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/result.dart';
import '../services/services.dart';
import 'returns_view_model.dart';
import 'sales_view_model.dart';
import 'session_view_model.dart';
import 'stock_view_model.dart';
import 'updates_view_model.dart';

enum DataStatus { idle, loading, ready }

/// Memuat seluruh data setelah login (tenant dulu, lalu stok/penjualan/retur paralel) dan menjaga
/// pengiriman antrean offline: saat jaringan kembali, tiap menit selama ada yang menunggu, dan sekali
/// saat dibuka.
class DataCoordinator extends ChangeNotifier {
  DataCoordinator({required this.session, required this.stock, required this.sales, required this.returns, required this.updates, required ToastService toast, Connectivity? connectivity})
      : _toast = toast,
        _connectivity = connectivity ?? Connectivity();

  final SessionViewModel session;
  final StockViewModel stock;
  final SalesViewModel sales;
  final ReturnsViewModel returns;
  final UpdatesViewModel updates;
  final ToastService _toast;
  final Connectivity _connectivity;

  DataStatus status = DataStatus.idle;
  bool online = true;

  StreamSubscription<List<ConnectivityResult>>? _net;
  Timer? _timer;

  bool _isOnline(List<ConnectivityResult> r) => r.any((c) => c != ConnectivityResult.none);

  /// Muat semua data. Mengembalikan false bila sesi tidak berlaku (harus login ulang).
  Future<bool> loadAll() async {
    status = DataStatus.loading;
    notifyListeners();

    final tenants = await session.loadTenants();
    await session.loadMenus();
    if (!session.menusLoaded) {
      _toast.show('Jatah menu belum bisa dimuat dari server, jadi sebagian menu disembunyikan. Periksa koneksi lalu muat ulang.', type: ToastType.warning, duration: const Duration(seconds: 9));
    }
    if (tenants case Err(:final error) when error.expired) return _expired();

    final results = await Future.wait([stock.load(), sales.load(), returns.load()]);
    final st = results[0] as StockLoad;
    final sa = results[1] as ({bool success, String? error, bool expired});
    final re = results[2] as ({bool success, String? error, bool expired});
    if (st.expired || sa.expired || re.expired) return _expired();

    if (st.offline) {
      // Tidak ada jaringan tapi ada salinan stok terakhir: cukup satu pemberitahuan, bukan galat per tabel.
      _toast.show('Mode offline: memakai data stok terakhir. Penjualan dikirim otomatis saat internet kembali.', type: ToastType.warning, duration: const Duration(seconds: 9));
    } else {
      // Stok baru dimuat dari database: kurangi dengan penjualan offline yang belum terkirim.
      sales.reapplyUnsynced();
      final gagal = [st.error, sa.error, re.error].whereType<String>();
      if (gagal.isNotEmpty) _toast.show('Data belum bisa dimuat: ${gagal.first}', type: ToastType.danger, duration: const Duration(seconds: 9));
    }

    status = DataStatus.ready;
    notifyListeners();
    return true;
  }

  bool _expired() {
    status = DataStatus.idle;
    notifyListeners();
    return false;
  }

  /// Mulai pantau jaringan dan kirim antrean. Dipanggil sekali setelah data termuat.
  Future<void> startSync() async {
    sales.onFlushed((summary) {
      if (summary.synced.isNotEmpty) _toast.show('${summary.synced.length} penjualan offline berhasil dikirim.', type: ToastType.success);
      if (summary.failed.isNotEmpty) {
        _toast.show('${summary.failed.length} penjualan offline ditolak database: ${summary.failed.first.error} Buka menu Akun untuk meninjaunya.', type: ToastType.danger, duration: const Duration(seconds: 12));
      }
    });
    online = _isOnline(await _connectivity.checkConnectivity());
    _net = _connectivity.onConnectivityChanged.listen((r) {
      final was = online;
      online = _isOnline(r);
      if (online != was) notifyListeners();
      if (online && !was) sales.flush();
    });
    _timer = Timer.periodic(AppConfig.outboxRetry, (_) {
      if (online && sales.outboxState.pending > 0) sales.flush();
    });
    unawaited(sales.flush());
  }

  void stopSync() {
    _net?.cancel();
    _timer?.cancel();
    _net = null;
    _timer = null;
    status = DataStatus.idle;
  }

  void clearAll() {
    stock.clear();
    sales.clear();
    returns.clear();
    stopSync();
    notifyListeners();
  }

  @override
  void dispose() {
    stopSync();
    super.dispose();
  }
}
