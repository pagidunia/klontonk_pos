import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../domain/report.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/period_report_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _currentText = {PeriodKind.harian: 'Hari ini', PeriodKind.mingguan: 'Minggu ini', PeriodKind.bulanan: 'Bulan ini'};
const _chartTitle = {PeriodKind.harian: 'Per jam', PeriodKind.mingguan: 'Per hari', PeriodKind.bulanan: 'Per tanggal'};
const _initialRows = 8;

PeriodReportViewModel createPeriodVm(AppDeps deps) => PeriodReportViewModel(sales: deps.sales, returns: deps.returns);

class StokKeluarPage extends StatelessWidget {
  const StokKeluarPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (_) => createPeriodVm(context.read<AppDeps>()), child: const _View());
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<PeriodReportViewModel>();
    final tenant = context.read<AppDeps>().session.currentTenant.name;
    final report = vm.salesReport;

    return PageScroll(children: [
      PageHeader(greeting: 'Stok · $tenant', title: 'Stok Keluar (Laku)', subtitle: 'Barang yang keluar akibat penjualan kasir.'),
      PeriodControls(vm: vm),
      if (report.trxCount == 0)
        SectionCard(child: EmptyNote(vm.isCurrent ? 'Penjualan dari menu Transaksi akan muncul di sini.' : 'Tidak ada barang keluar pada periode ini.', action: FilledButton(onPressed: () => context.go('/kasir'), child: const Text('Buka Transaksi'))))
      else ...[
        StatGrid(children: [
          StatBox(label: 'Item terjual', value: formatQty(report.itemCount), sub: '${report.kindCount} jenis barang'),
          StatBox(label: 'Transaksi', value: formatQty(report.trxCount), sub: 'rata-rata ${(report.itemCount / report.trxCount).toStringAsFixed(1)} item'),
          StatBox(label: 'Omzet', value: formatRupiah(report.revenue)),
        ]),
        SectionCard(title: 'Item Terjual', count: _chartTitle[vm.kind], child: SalesBarChart(report: report, kind: vm.kind)),
        SectionCard(
          title: 'Barang Keluar',
          count: '${report.kindCount} jenis',
          child: Column(children: [
            for (var i = 0; i < report.items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  CircleAvatar(radius: 13, backgroundColor: i < 3 ? p.primary : p.surface2, child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i < 3 ? Colors.white : p.textSecondary))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(report.items[i].name, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${formatQty(report.items[i].qty)} ${report.items[i].unit}', style: const TextStyle(fontWeight: FontWeight.w800)), Text(formatRupiah(report.items[i].revenue), style: TextStyle(fontSize: 12, color: p.textSecondary))]),
                ]),
              ),
          ]),
        ),
        SalesHistory(report: report, kind: vm.kind, showAll: vm.showAllTrx, onToggle: vm.toggleShowAll),
      ],
    ]);
  }
}

/// Tab periode + navigasi (dipakai halaman Stok Keluar dan laporan).
class PeriodControls extends StatelessWidget {
  const PeriodControls({super.key, required this.vm});
  final PeriodReportViewModel vm;

  @override
  Widget build(BuildContext context) => Column(children: [
        SegmentTabs<PeriodKind>(value: vm.kind, options: periodLabels, onChanged: vm.setKind),
        PeriodNav(label: vm.label, isCurrent: vm.isCurrent, currentText: _currentText[vm.kind]!, onPrev: () => vm.shift(-1), onNext: () => vm.shift(1), onToday: vm.today),
      ]);
}

class SalesBarChart extends StatelessWidget {
  const SalesBarChart({super.key, required this.report, required this.kind});
  final SalesReport report;
  final PeriodKind kind;

  @override
  Widget build(BuildContext context) => BarChart(
        values: [for (final b in report.buckets) b.qty],
        labels: [for (final b in report.buckets) b.label],
        subLabels: kind == PeriodKind.mingguan ? [for (final b in report.buckets) b.sub] : null,
      );
}

class SalesHistory extends StatelessWidget {
  const SalesHistory({super.key, required this.report, required this.kind, required this.showAll, required this.onToggle});
  final SalesReport report;
  final PeriodKind kind;
  final bool showAll;
  final VoidCallback onToggle;

  String _time(Sale s) => kind == PeriodKind.harian ? formatTime(s.at) : formatWhen(s.at);

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final shown = showAll ? report.sales : report.sales.take(_initialRows).toList();
    return SectionCard(
      title: 'Riwayat Penjualan',
      count: '${report.sales.length} transaksi',
      child: Column(children: [
        for (final s in shown)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_time(s), style: const TextStyle(fontWeight: FontWeight.w800)), Text(formatRupiah(s.total), style: const TextStyle(fontWeight: FontWeight.w800))]),
              subtitle: Text('${s.no} · ${s.itemCount} item · ${methodLabel(s.method)}', style: TextStyle(fontSize: 12, color: p.textSecondary)),
              children: [
                for (final l in s.lines) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text('${l.name}  ${formatQty(l.qty)} ${l.unit} × ${formatRupiah(l.price)}', style: const TextStyle(fontSize: 13))), Text(formatRupiah(l.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))])),
                Align(alignment: Alignment.centerLeft, child: Text('Kasir: ${s.cashier}', style: TextStyle(fontSize: 12, color: p.textMuted))),
                if (s.failed) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Ditolak database: ${s.reviewNote}', style: TextStyle(fontSize: 12, color: p.danger, fontWeight: FontWeight.w700)))
                else if (s.pending) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Dibuat offline, belum terkirim ke server.', style: TextStyle(fontSize: 12, color: p.warning, fontWeight: FontWeight.w700)))
                else if (s.reviewNote != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Perlu ditinjau: ${s.reviewNote}', style: TextStyle(fontSize: 12, color: p.warning, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        if (report.sales.length > _initialRows) TextButton(onPressed: onToggle, child: Text(showAll ? 'Tampilkan lebih sedikit' : 'Tampilkan semua (${report.sales.length})')),
      ]),
    );
  }
}
