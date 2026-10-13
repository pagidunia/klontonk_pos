import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/stok_total_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StokTotalPage extends StatelessWidget {
  const StokTotalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(
      create: (_) => StokTotalViewModel(stock: deps.stock, sales: deps.sales),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  static const _filters = {StockFilter.semua: 'Semua', StockFilter.menipis: 'Menipis', StockFilter.habis: 'Habis'};

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<StokTotalViewModel>();
    final session = context.read<AppDeps>().session;
    final sold = vm.soldById;
    final list = vm.visible;

    return PageScroll(children: [
      PageHeader(greeting: 'Stok · ${session.currentTenant.name}', title: 'Stok Total', subtitle: 'Sisa stok terakhir setelah semua transaksi kasir.'),
      StatGrid(children: [
        StatBox(label: 'Jenis barang', value: '${vm.total}'),
        StatBox(label: 'Menipis', value: '${vm.low}', sub: 'sisa ≤ ${AppConfig.lowStockMax}', color: vm.low > 0 ? p.warning : null),
        StatBox(label: 'Habis', value: '${vm.out}', sub: 'sisa 0', color: vm.out > 0 ? p.danger : null),
      ]),
      SectionCard(
        title: 'Daftar Sisa Stok',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(onChanged: vm.setQuery, decoration: const InputDecoration(hintText: 'Cari nama atau barcode', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 10),
          SegmentTabs<StockFilter>(value: vm.filter, options: _filters, onChanged: vm.setFilter),
          const SizedBox(height: 6),
          if (vm.total == 0)
            const EmptyNote('Belum ada barang. Tambahkan lewat menu Stok Awal.')
          else if (list.isEmpty)
            const EmptyNote('Tidak ada barang yang cocok.')
          else
            for (final item in list)
              () {
                final status = statusOf(item.qty);
                final color = switch (status) { StockStatus.aman => p.success, StockStatus.menipis => p.warning, StockStatus.habis => p.danger };
                final text = switch (status) { StockStatus.aman => 'Aman', StockStatus.menipis => 'Menipis', StockStatus.habis => 'Habis' };
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text('Terjual ${formatQty(sold[item.id] ?? 0)} ${item.unit}${item.barcode == null ? '' : ' · ${item.barcode}'}', style: TextStyle(fontSize: 12, color: p.textSecondary))])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${formatQty(item.qty)} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Pill(text, color: color)]),
                  ]),
                );
              }(),
        ]),
      ),
    ]);
  }
}
