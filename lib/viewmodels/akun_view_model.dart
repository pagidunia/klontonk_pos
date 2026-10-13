import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../data/local/local_stores.dart';
import '../data/models/models.dart';
import '../services/services.dart';
import 'sales_view_model.dart';
import 'session_view_model.dart';
import 'theme_view_model.dart';

/// Akun & Pengaturan: info akun, antrean penjualan offline, tema, dan cetak otomatis.
class AkunViewModel extends ChangeNotifier {
  AkunViewModel({required this.session, required this.sales, required this.theme, required this.prefs, required this.toast, required this.confirm}) {
    sales.addListener(notifyListeners);
  }
  final SessionViewModel session;
  final SalesViewModel sales;
  final ThemeViewModel theme;
  final PreferencesStore prefs;
  final ToastService toast;
  final Future<bool> Function({required String title, required String message}) confirm;

  String get version => AppConfig.appVersion;
  OutboxState get outbox => sales.outboxState;
  bool get autoPrint => prefs.autoPrint;

  void setAutoPrint(bool on) {
    prefs.setAutoPrint(on);
    notifyListeners();
  }

  Future<void> flushNow() async {
    final summary = await sales.flush();
    if (summary.synced.isEmpty && summary.failed.isEmpty) {
      toast.show(summary.stopped == null ? 'Tidak ada penjualan yang menunggu.' : 'Belum bisa terkirim. Periksa koneksi internet.', type: ToastType.warning);
    }
  }

  Future<void> retry(OutboxEntry entry) async {
    await sales.retry(entry.clientId);
  }

  Future<void> discard(OutboxEntry entry) async {
    final yakin = await confirm(title: 'Buang Penjualan', message: 'Penjualan ini TIDAK akan tercatat di database. Lanjutkan?');
    if (yakin) await sales.discard(entry.clientId);
  }

  @override
  void dispose() {
    sales.removeListener(notifyListeners);
    super.dispose();
  }
}
