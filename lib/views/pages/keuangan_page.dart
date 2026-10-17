import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../domain/finance.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/keuangan_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

class KeuanganPage extends StatelessWidget {
  const KeuanganPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(create: (_) => KeuanganViewModel(sales: deps.sales, returns: deps.returns), child: const _View());
  }
}

const _currentText = {FinanceMode.harian: 'Hari ini', FinanceMode.bulanan: 'Bulan ini', FinanceMode.tahunan: 'Tahun ini', FinanceMode.custom: ''};

class _View extends StatelessWidget {
  const _View();

  Future<void> _pickRange(BuildContext context, KeuanganViewModel vm) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: vm.customStart, end: vm.customEnd),
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
    );
    if (picked != null) vm.setCustom(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<KeuanganViewModel>();
    final s = vm.summary;
    final tenant = context.read<AppDeps>().session.currentTenant.name;
    final custom = vm.mode == FinanceMode.custom;
    final peak = s.peak;

    return PageScroll(children: [
      PageHeader(greeting: 'Laporan · $tenant', title: 'Laporan Keuangan', subtitle: 'Omzet, retur, dan arus kas bersih dari penjualan.'),
      SegmentTabs<FinanceMode>(value: vm.mode == FinanceMode.custom ? FinanceMode.harian : vm.mode, options: financeLabels, onChanged: vm.setMode),
      const SizedBox(height: 4),
      if (custom)
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Column(children: [Text(vm.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), TextButton(onPressed: () => vm.setMode(FinanceMode.harian), child: const Text('Kembali ke periode')) ]))
      else
        PeriodNav(label: vm.label, isCurrent: vm.isCurrent, currentText: _currentText[vm.mode]!, onPrev: () => vm.shift(-1), onNext: () => vm.shift(1), onToday: vm.today),
      OutlinedButton.icon(onPressed: () => _pickRange(context, vm), icon: const Icon(Icons.date_range_outlined), label: const Text('Pilih rentang tanggal')),
      const SizedBox(height: 14),
      StatGrid(children: [
        StatBox(label: 'Omzet', value: formatRupiah(s.omzet), sub: '${s.trx} transaksi'),
        StatBox(label: 'Retur pelanggan', value: formatRupiah(s.refund), color: s.refund > 0 ? p.danger : null),
        StatBox(label: 'Arus kas bersih', value: formatRupiah(s.net), color: p.success),
        StatBox(label: 'Rata-rata / transaksi', value: formatRupiah(s.avg.round())),
      ]),
      SectionCard(
        title: 'Omzet',
        count: vm.mode == FinanceMode.harian ? 'per jam' : (vm.mode == FinanceMode.tahunan ? 'per bulan' : 'per hari'),
        child: peak == 0 ? const EmptyNote('Belum ada penjualan pada periode ini.') : BarChart(values: [for (final b in s.buckets) b.revenue], labels: [for (final b in s.buckets) b.label], subLabels: custom && s.buckets.length <= 12 ? [for (final b in s.buckets) b.sub] : null, color: p.success),
      ),
      SectionCard(
        title: 'Metode Pembayaran',
        child: Column(children: [InfoRow('Tunai', formatRupiah(s.tunai)), InfoRow('QRIS / Transfer', formatRupiah(s.nontunai)), InfoRow('Utang (belum diterima)', formatRupiah(s.utang), last: true)]),
      ),
      if (s.cashiers.isNotEmpty)
        SectionCard(title: 'Per Kasir', child: Column(children: [for (var i = 0; i < s.cashiers.length; i++) InfoRow('${s.cashiers[i].name} · ${s.cashiers[i].trx} trx', formatRupiah(s.cashiers[i].revenue), last: i == s.cashiers.length - 1)])),
      if (s.items.isNotEmpty)
        SectionCard(title: 'Omzet per Barang', count: '${s.items.length} jenis', child: Column(children: [for (var i = 0; i < s.items.length && i < 15; i++) InfoRow('${s.items[i].name} · ${formatQty(s.items[i].qty)} ${s.items[i].unit}', formatRupiah(s.items[i].revenue), last: i == (s.items.length < 15 ? s.items.length : 15) - 1)])),
    ]);
  }
}
