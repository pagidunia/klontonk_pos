import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../core/result.dart';
import '../data/local/local_stores.dart';
import '../data/models/models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/sales_repository.dart';
import '../domain/outbox_logic.dart';
import '../domain/sync.dart';
import 'session_view_model.dart';
import 'stock_view_model.dart';

const offlineNoPrefix = 'OFF-';

sealed class CheckoutResult {
  const CheckoutResult();
}

final class CheckoutOk extends CheckoutResult {
  const CheckoutOk(this.sale, {this.offline = false});
  final Sale sale;

  /// true bila tersimpan di antrean perangkat (belum di database).
  final bool offline;
}

final class CheckoutFail extends CheckoutResult {
  const CheckoutFail(this.error);
  final String error;
}

typedef OutboxState = ({int pending, int failed, List<OutboxEntry> entries});

/// Riwayat penjualan per tenant + antrean offline. Penjualan baru dicatat HANYA lewat checkout():
/// satu fungsi di database yang mengunci stok, memeriksa cukup, mengurangi stok, menghitung total dari
/// harga di database, membuat nomor transaksi, dan menyimpan penjualannya dalam satu transaksi.
///
/// Saat OFFLINE, checkout() menyimpan penjualan ke antrean di perangkat dan mengurangi stok salinan
/// lokal; [flush] mengirimnya begitu ada jaringan. Tiap penjualan membawa UUID (client_id) sehingga
/// pengiriman ulang tidak pernah menggandakannya.
class SalesViewModel extends ChangeNotifier {
  SalesViewModel({required SalesRepository repo, required AuthRepository auth, required SessionViewModel session, required StockViewModel stock, required OutboxStore outbox, bool Function()? isOnline, String Function()? newClientId})
      : _repo = repo,
        _auth = auth,
        _session = session,
        _stock = stock,
        _outbox = outbox,
        _isOnline = isOnline ?? (() => true),
        _newClientId = newClientId ?? (() => const Uuid().v4());

  final SalesRepository _repo;
  final AuthRepository _auth;
  final SessionViewModel _session;
  final StockViewModel _stock;
  final OutboxStore _outbox;
  final bool Function() _isOnline;
  final String Function() _newClientId;

  Map<String, List<Sale>> _data = {};
  Set<String> _syncedClientIds = {};
  Future<FlushSummary>? _flushing;
  final _flushListeners = <void Function(FlushSummary)>[];

  List<Sale> get sales => List.unmodifiable(_data[_session.tenantId] ?? const []);

  void clear() {
    _data = {};
    _syncedClientIds = {};
    notifyListeners();
  }

  OutboxState get outboxState {
    final entries = _outbox.list();
    return (pending: entries.where((e) => e.isPending).length, failed: entries.where((e) => e.isFailed).length, entries: entries);
  }

  void onFlushed(void Function(FlushSummary summary) handler) => _flushListeners.add(handler);

  Sale _entryToSale(OutboxEntry e) => Sale(
        no: offlineNoPrefix + e.clientId.replaceAll('-', '').substring(0, 8).toUpperCase(),
        at: e.at,
        cashier: e.cashier,
        method: e.method,
        total: e.expectedTotal,
        paid: e.paid,
        offline: true,
        pending: true,
        failed: e.isFailed,
        reviewNote: e.isFailed ? e.error : null,
        clientId: e.clientId,
        lines: e.lines,
      );

  String _describe(AppError e) => describeError(e, forbidden: 'Tidak punya akses untuk transaksi ini.');

  /// Muat riwayat (RLS: admin semua tenant, kasir hanya tenant sendiri). Penjualan yang masih di
  /// antrean perangkat ditambahkan agar tetap tampil di laporan.
  Future<({bool success, String? error, bool expired})> load() async {
    final result = await _repo.fetchAll();
    switch (result) {
      case Err(:final error):
        // Offline saat aplikasi dibuka: setidaknya penjualan di antrean tetap tampil.
        if (error.isNetwork && _data.isEmpty) {
          final grouped = <String, List<Sale>>{};
          for (final e in _outbox.list()) {
            (grouped[e.tenant] ??= []).add(_entryToSale(e));
          }
          _data = grouped;
          notifyListeners();
        }
        return (success: false, error: _describe(error), expired: error.expired);
      case Ok(:final data):
        final grouped = <String, List<Sale>>{for (final t in _session.tenants) t.id: <Sale>[], ...data.byTenant.map((k, v) => MapEntry(k, List<Sale>.of(v)))};
        _syncedClientIds = data.clientIds;
        for (final e in _outbox.list()) {
          if (!_syncedClientIds.contains(e.clientId)) (grouped[e.tenant] ??= []).add(_entryToSale(e));
        }
        _data = grouped;
        notifyListeners();
        return (success: true, error: null, expired: false);
    }
  }

  /// Proses pembayaran. Hanya gangguan jaringan yang masuk antrean; penolakan database (stok kurang,
  /// harga kosong, dst.) ditampilkan ke kasir.
  Future<CheckoutResult> checkout({required String method, required int paid, required List<CartLine> lines}) async {
    final tenant = _session.tenantId;
    final clientId = _newClientId();
    final reqLines = [for (final l in lines) (id: l.id, qty: l.qty)];

    Future<Result<Sale>> call(Map<String, Object?> extra) => _repo.checkout(tenant: tenant, method: method, paid: paid, lines: reqLines, extra: extra);

    var result = await call({'p_client_id': clientId});
    if (result case Err(:final error) when error.code == schemaMissing) {
      // Database belum diperbarui ke checkout versi baru: pakai panggilan lama agar kasir tetap bisa berjualan.
      result = await call(const {});
    }

    switch (result) {
      case Ok(:final data):
        _data = {..._data, tenant: [...(_data[tenant] ?? const []), data]};
        _stock.applySale(data.lines);
        notifyListeners();
        return CheckoutOk(data);
      case Err(:final error):
        if (!error.isNetwork) return CheckoutFail(_describe(error));
        return _queueOffline(tenant: tenant, clientId: clientId, method: method, paid: paid, lines: lines);
    }
  }

  Future<CheckoutResult> _queueOffline({required String tenant, required String clientId, required String method, required int paid, required List<CartLine> lines}) async {
    final uid = _auth.currentUserId;
    if (uid == null) return const CheckoutFail('Tidak ada koneksi dan sesi login tidak ditemukan. Sambungkan internet untuk masuk lagi.');

    final built = buildEntry(
      clientId: clientId,
      tenant: tenant,
      userId: uid,
      cashier: _session.user?.name ?? 'Kasir',
      method: method,
      paid: paid,
      lines: [for (final l in lines) SaleLine(id: l.id, name: l.name, unit: l.unit, qty: l.qty, price: l.price)],
    );
    if (built.error != null) return CheckoutFail(built.error!);

    final stored = await _outbox.add(built.entry!);
    if (!stored.ok) return CheckoutFail(stored.error!);

    final sale = _entryToSale(built.entry!);
    _data = {..._data, tenant: [...(_data[tenant] ?? const []), sale]};
    _stock.applySale(sale.lines);
    notifyListeners();
    return CheckoutOk(sale, offline: true);
  }

  /// Kirim satu entri antrean; database mengenali client_id sehingga pengulangan aman.
  Future<Result<Sale>> _send(OutboxEntry e) async {
    final result = await _repo.checkout(
      tenant: e.tenant,
      method: e.method,
      paid: e.paid,
      lines: [for (final l in e.lines) (id: l.id, qty: l.qty)],
      extra: {'p_client_id': e.clientId, 'p_offline': true, 'p_at': e.at.toUtc().toIso8601String(), 'p_expected_total': e.expectedTotal},
      timeout: AppConfig.checkoutTimeout * 2,
    );
    if (result case Err(:final error)) return Err(AppError(status: error.status, code: error.code, message: _describe(error), expired: error.expired));
    return result;
  }

  Future<void> _reloadFromServer() async {
    final stock = await _stock.load();
    await load();
    // Bila jaringan putus di tengah jalan, stok berasal dari salinan offline yang sudah memuat pengurangannya.
    if (!stock.offline) reapplyUnsynced();
  }

  /// Kirim antrean offline ke database. Aman dipanggil berulang/bersamaan: satu proses sekaligus.
  Future<FlushSummary> flush() {
    final running = _flushing;
    if (running != null) return running;
    final future = _doFlush().whenComplete(() => _flushing = null);
    _flushing = future;
    return future;
  }

  Future<FlushSummary> _doFlush() async {
    final uid = _auth.currentUserId;
    if (uid == null) return FlushSummary(stopped: 'no-session');
    if (_outbox.count('pending') == 0) return FlushSummary();

    final summary = await flushOutbox(outbox: _outbox, send: _send, userId: uid, isOnline: _isOnline);
    if (summary.synced.isNotEmpty) await _reloadFromServer();
    if (summary.synced.isNotEmpty || summary.failed.isNotEmpty) {
      for (final handler in _flushListeners) {
        handler(summary);
      }
    }
    notifyListeners();
    return summary;
  }

  /// Setelah stok dimuat dari database: kurangi lagi dengan penjualan yang belum ada di database
  /// (masih di antrean, atau ditolak dan menunggu keputusan). JANGAN dipanggil bila stok berasal
  /// dari salinan offline: salinan itu sudah memuat pengurangannya.
  void reapplyUnsynced() {
    for (final e in _outbox.list()) {
      if (_syncedClientIds.contains(e.clientId)) continue;
      if (e.tenant == _session.tenantId) _stock.applySale(e.lines);
    }
  }

  /// Coba kirim ulang penjualan yang ditolak (mis. setelah admin mengisi harga barangnya).
  Future<FlushSummary> retry(String clientId) async {
    await _outbox.update(clientId, (e) => e.copyWith(status: 'pending', clearError: true));
    notifyListeners();
    return flush();
  }

  /// Buang penjualan yang ditolak dari antrean. Penjualannya TIDAK akan tercatat di database.
  Future<void> discard(String clientId) async {
    await _outbox.remove(clientId);
    notifyListeners();
    await _reloadFromServer();
  }
}
