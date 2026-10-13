import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/home_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(stock: deps.stock, sales: deps.sales, returns: deps.returns, session: deps.session),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<HomeViewModel>();
    final session = vm.session;
    final now = DateTime.now();
    final stats = vm.stats(now);
    final accents = [p.primary, p.success, p.warning, p.info];
    final activity = vm.activity();

    final quick = [
      (Icons.point_of_sale, 'Transaksi', 'Transaksi penjualan baru', '/kasir'),
      (Icons.inventory_2_outlined, 'Cek Stok', 'Lihat stok total', '/stok/total'),
      if (session.canEditStock) (Icons.sell_outlined, 'Update Harga', 'Sesuaikan harga produk', '/harga'),
      (Icons.description_outlined, 'Laporan Kasir', 'Cetak / preview laporan', '/laporan/stok-awal'),
      (Icons.assignment_return_outlined, 'Retur Barang', 'Proses retur cepat', '/stok/retur'),
    ];

    return PageScroll(children: [
      PageHeader(greeting: '${sapaan(now)} · ${session.currentTenant.name}', title: 'Dashboard Klontonk', subtitle: 'Ringkasan operasional hari ini, ${namaHari[(now.weekday + 6) % 7]}, ${now.day} ${namaBulan[now.month - 1]}'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.25,
        children: [
          for (var i = 0; i < stats.length; i++) _StatCard(info: stats[i], accent: accents[i]),
        ],
      ),
      const SizedBox(height: 22),
      const Text('Aksi Cepat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          for (final q in quick)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.go(q.$4),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(10)), child: Icon(q.$1, color: p.primary, size: 20)),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(q.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), Text(q.$3, style: TextStyle(fontSize: 11.5, color: p.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)]),
                ]),
              ),
            ),
        ],
      ),
      const SizedBox(height: 22),
      SectionCard(
        title: 'Aktivitas Terbaru',
        child: activity.isEmpty
            ? const EmptyNote('Belum ada transaksi atau retur di tenant ini.')
            : Column(children: [
                for (final a in activity)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(margin: const EdgeInsets.only(top: 5, right: 12), width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: a.kind == 'sale' ? p.success : (a.kind == 'pelanggan' ? p.warning : p.info))),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)), Text(a.meta, style: TextStyle(fontSize: 12, color: p.textSecondary))])),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.info, required this.accent});
  final StatInfo info;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final trendColor = switch (info.trend) { Trend.up => p.success, Trend.down => p.danger, Trend.flat => p.textMuted };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: accent, width: 4), top: BorderSide(color: p.border), right: BorderSide(color: p.border), bottom: BorderSide(color: p.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(info.label, style: TextStyle(fontSize: 12, color: p.textSecondary, fontWeight: FontWeight.w600)),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(info.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        Text(info.note, style: TextStyle(fontSize: 11, color: trendColor, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
