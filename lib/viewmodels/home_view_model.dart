import 'package:flutter/foundation.dart';

import '../core/calendar.dart';
import '../core/config.dart';
import '../core/format.dart';
import 'returns_view_model.dart';
import 'sales_view_model.dart';
import 'session_view_model.dart';
import 'stock_view_model.dart';

enum Trend { up, down, flat }

class StatInfo {
  const StatInfo({required this.label, required this.value, required this.trend, required this.note});
  final String label;
  final String value;
  final Trend trend;
  final String note;
}

class ActivityItem {
  const ActivityItem({required this.at, required this.title, required this.meta, required this.kind});
  final DateTime at;
  final String title;
  final String meta;
  final String kind; // 'sale' | 'pelanggan' | 'supplier'
}

Trend _trendDir(num today, num yesterday) => today > yesterday ? Trend.up : (today < yesterday ? Trend.down : Trend.flat);

({Trend dir, String text}) trend(num today, num yesterday) {
  if (yesterday <= 0) return today > 0 ? (dir: Trend.up, text: '↑ transaksi pertama hari ini') : (dir: Trend.flat, text: 'Belum ada transaksi');
  final pct = ((today - yesterday) / yesterday * 100).round();
  if (pct == 0) return (dir: Trend.flat, text: 'Sama seperti kemarin');
  return (dir: _trendDir(today, yesterday), text: '${pct > 0 ? '↑' : '↓'} ${pct.abs()}% dari kemarin');
}

/// Beranda: ringkasan hari ini dan aktivitas terbaru (turunan dari stok, penjualan, dan retur).
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required this.stock, required this.sales, required this.returns, required this.session}) {
    for (final l in [stock, sales, returns]) {
      l.addListener(notifyListeners);
    }
  }
  final StockViewModel stock;
  final SalesViewModel sales;
  final ReturnsViewModel returns;
  final SessionViewModel session;

  List<StatInfo> stats([DateTime? now]) {
    final today = now ?? DateTime.now();
    final yesterday = addDays(today, -1);
    final all = sales.sales;
    final todaySales = all.where((s) => isSameDay(s.at.toLocal(), today)).toList();
    final yesterdaySales = all.where((s) => isSameDay(s.at.toLocal(), yesterday)).toList();
    final omzetToday = todaySales.fold(0, (s, x) => s + x.total);
    final omzetYesterday = yesterdaySales.fold(0, (s, x) => s + x.total);
    final low = stock.items.where((i) => i.qty <= AppConfig.lowStockMax).length;
    final retToday = returns.items.where((r) => isSameDay(r.at.toLocal(), today)).length;

    final omzetTrend = trend(omzetToday, omzetYesterday);
    final trxTrend = trend(todaySales.length, yesterdaySales.length);
    return [
      StatInfo(label: 'Omzet Hari Ini', value: formatRupiah(omzetToday), trend: omzetTrend.dir, note: omzetTrend.text),
      StatInfo(label: 'Transaksi Hari Ini', value: '${todaySales.length}', trend: trxTrend.dir, note: trxTrend.text),
      StatInfo(label: 'Item Stok Rendah', value: '$low', trend: low > 0 ? Trend.down : Trend.up, note: low > 0 ? 'Perlu restok' : 'Stok aman'),
      StatInfo(label: 'Retur Hari Ini', value: '$retToday', trend: Trend.flat, note: 'transaksi retur'),
    ];
  }

  List<ActivityItem> activity() {
    final items = [
      for (final s in sales.sales) ActivityItem(at: s.at, title: 'Transaksi ${s.no} berhasil', meta: '${relativeTime(s.at)} · ${formatRupiah(s.total)}', kind: 'sale'),
      for (final r in returns.items)
        ActivityItem(at: r.at, title: 'Retur ${r.kind == 'pelanggan' ? 'dari pelanggan' : 'ke supplier'}: ${r.name} ${formatQty(r.qty)} ${r.unit}', meta: '${relativeTime(r.at)} · oleh ${r.cashier}', kind: r.kind),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return items.take(5).toList();
  }

  @override
  void dispose() {
    for (final l in [stock, sales, returns]) {
      l.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
