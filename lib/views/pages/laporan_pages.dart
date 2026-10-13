import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/period_report_view_model.dart';
import '../../viewmodels/returns_view_model.dart';
import '../../viewmodels/stok_total_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'stok_keluar_page.dart';

/// Kepala kartu laporan: judul, cabang, waktu cetak, dan tombol bagikan.
class _ReportHead extends StatelessWidget {
  const _ReportHead({required this.title, required this.onShare});
  final String title;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    final user = deps.session.user;
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), Text('${deps.session.currentTenant.name} · Dicetak ${formatDateTime(DateTime.now())}${user == null ? '' : ' oleh ${user.name}'}', style: TextStyle(fontSize: 12, color: context.pal.textSecondary))])),
      OutlinedButton.icon(onPressed: onShare, icon: const Icon(Icons.ios_share, size: 18), label: const Text('Bagikan'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40))),
    ]);
  }
}

void _share(BuildContext context, String title, List<String> lines) {
  final deps = context.read<AppDeps>();
  final teks = StringBuffer()
    ..writeln(title)
    ..writeln('${deps.session.currentTenant.name} · ${formatDateTime(DateTime.now())}')
    ..writeln()
    ..writeAll(lines, '\n');
  Share.share(teks.toString(), subject: title);
}

class _Table extends StatelessWidget {
  const _Table({required this.head, required this.rows, this.flex = const []});
  final List<String> head;
  final List<List<String>> rows;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    int f(int i) => i < flex.length ? flex[i] : 1;
    Widget row(List<String> cells, {bool header = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
          child: Row(children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(flex: f(i), child: Text(cells[i], textAlign: i == 0 ? TextAlign.start : TextAlign.end, style: TextStyle(fontSize: header ? 11.5 : 12.5, fontWeight: header || i == 0 ? FontWeight.w700 : FontWeight.w500, color: header ? p.textSecondary : p.text))),
          ]),
        );
    return Column(children: [row(head, header: true), for (final r in rows) row(r)]);
  }
}

// ---------------- Laporan Stok Awal ----------------

class LaporanStokAwalPage extends StatelessWidget {
  const LaporanStokAwalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ListenableBuilder(
      listenable: deps.stock,
      builder: (context, _) {
        final items = [...deps.stock.items]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final priced = items.where((i) => i.hasPrice).length;
        final value = items.fold(0, (s, i) => s + (i.hasPrice ? i.qty * i.price! : 0));
        final rows = [for (final i in items) [i.name, '${formatQty(i.qty)} ${i.unit}', i.hasPrice ? formatRupiah(i.price!) : '—', i.hasPrice ? formatRupiah(i.qty * i.price!) : '—']];
        return PageScroll(children: [
          PageHeader(greeting: 'Laporan · ${deps.session.currentTenant.name}', title: 'Laporan Stok Awal', subtitle: 'Daftar stok saat ini, siap dibagikan atau dicetak.'),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _ReportHead(title: 'Laporan Stok Awal', onShare: () => _share(context, 'Laporan Stok Awal', [for (final r in rows) '${r[0]} | ${r[1]} | ${r[2]} | ${r[3]}'])),
              const SizedBox(height: 14),
              StatGrid(children: [StatBox(label: 'Jenis Barang', value: '${items.length}'), StatBox(label: 'Sudah Berharga', value: '$priced', sub: 'dari ${items.length}'), StatBox(label: 'Estimasi Nilai Stok', value: formatRupiah(value))]),
              if (items.isEmpty) const EmptyNote('Belum ada barang di Stok Awal.') else _Table(head: const ['Nama Barang', 'Jumlah', 'Harga', 'Subtotal'], rows: rows, flex: const [3, 2, 2, 2]),
            ]),
          ),
        ]);
      },
    );
  }
}

// ---------------- Laporan Stok Keluar ----------------

class LaporanStokKeluarPage extends StatelessWidget {
  const LaporanStokKeluarPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (_) => createPeriodVm(context.read<AppDeps>()), child: const _KeluarView());
}

class _KeluarView extends StatelessWidget {
  const _KeluarView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PeriodReportViewModel>();
    final r = vm.salesReport;
    final title = 'Laporan Stok Keluar — ${vm.label}';
    return PageScroll(children: [
      PageHeader(greeting: 'Laporan · ${context.read<AppDeps>().session.currentTenant.name}', title: 'Laporan Stok Keluar', subtitle: 'Barang keluar akibat penjualan per periode.'),
      PeriodControls(vm: vm),
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ReportHead(title: 'Laporan Stok Keluar (Laku)', onShare: () => _share(context, title, ['Item terjual: ${formatQty(r.itemCount)}', 'Transaksi: ${r.trxCount}', 'Omzet: ${formatRupiah(r.revenue)}', '', for (final i in r.items) '${i.name} | ${formatQty(i.qty)} ${i.unit} | ${formatRupiah(i.revenue)}'])),
          const SizedBox(height: 14),
          StatGrid(children: [StatBox(label: 'Item terjual', value: formatQty(r.itemCount), sub: '${r.kindCount} jenis'), StatBox(label: 'Transaksi', value: '${r.trxCount}'), StatBox(label: 'Omzet', value: formatRupiah(r.revenue))]),
          if (r.items.isEmpty) const EmptyNote('Tidak ada penjualan pada periode ini.') else _Table(head: const ['Barang', 'Jumlah', 'Omzet'], rows: [for (final i in r.items) [i.name, '${formatQty(i.qty)} ${i.unit}', formatRupiah(i.revenue)]], flex: const [3, 2, 2]),
        ]),
      ),
    ]);
  }
}

// ---------------- Laporan Stok Retur ----------------

class LaporanStokReturPage extends StatelessWidget {
  const LaporanStokReturPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (_) => createPeriodVm(context.read<AppDeps>()), child: const _ReturView());
}

class _ReturView extends StatelessWidget {
  const _ReturView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PeriodReportViewModel>();
    final list = vm.returnsInRange;
    final customer = list.where((r) => r.kind == 'pelanggan').toList();
    final supplier = list.where((r) => r.kind == 'supplier').toList();
    final refund = customer.fold(0, (s, r) => s + r.amount);
    final title = 'Laporan Stok Retur — ${vm.label}';
    List<String> line(StockReturn r) => [formatWhen(r.at), r.kind == 'pelanggan' ? 'Pelanggan' : 'Supplier', r.name, '${formatQty(r.qty)} ${r.unit}', r.kind == 'pelanggan' ? formatRupiah(r.amount) : '—'];
    return PageScroll(children: [
      PageHeader(greeting: 'Laporan · ${context.read<AppDeps>().session.currentTenant.name}', title: 'Laporan Stok Retur', subtitle: 'Retur pelanggan dan barang rusak per periode.'),
      PeriodControls(vm: vm),
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ReportHead(title: 'Laporan Stok Retur', onShare: () => _share(context, title, [for (final r in list) '${line(r).join(' | ')} | ${reasonLabel(r.reason)}'])),
          const SizedBox(height: 14),
          StatGrid(children: [StatBox(label: 'Retur pelanggan', value: '${customer.length}'), StatBox(label: 'Retur supplier', value: '${supplier.length}'), StatBox(label: 'Uang dikembalikan', value: formatRupiah(refund))]),
          if (list.isEmpty) const EmptyNote('Tidak ada retur pada periode ini.') else _Table(head: const ['Waktu', 'Jenis', 'Barang', 'Jumlah', 'Nilai'], rows: [for (final r in list) line(r)], flex: const [2, 2, 3, 2, 2]),
        ]),
      ),
    ]);
  }
}

// ---------------- Laporan Stok Total ----------------

class LaporanStokTotalPage extends StatelessWidget {
  const LaporanStokTotalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    final p = context.pal;
    return ListenableBuilder(
      listenable: Listenable.merge([deps.stock, deps.sales]),
      builder: (context, _) {
        final items = [...deps.stock.items]..sort((a, b) => a.qty.compareTo(b.qty));
        final low = items.where((i) => statusOf(i.qty) == StockStatus.menipis).length;
        final out = items.where((i) => statusOf(i.qty) == StockStatus.habis).length;
        final rows = [for (final i in items) [i.name, '${formatQty(i.qty)} ${i.unit}', switch (statusOf(i.qty)) { StockStatus.aman => 'Aman', StockStatus.menipis => 'Menipis', StockStatus.habis => 'Habis' }]];
        return PageScroll(children: [
          PageHeader(greeting: 'Laporan · ${deps.session.currentTenant.name}', title: 'Laporan Stok Total', subtitle: 'Sisa stok terkini, yang menipis tampil lebih dulu.'),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _ReportHead(title: 'Laporan Stok Total', onShare: () => _share(context, 'Laporan Stok Total', [for (final r in rows) r.join(' | ')])),
              const SizedBox(height: 14),
              StatGrid(children: [StatBox(label: 'Jenis barang', value: '${items.length}'), StatBox(label: 'Menipis', value: '$low', sub: 'sisa ≤ ${AppConfig.lowStockMax}', color: low > 0 ? p.warning : null), StatBox(label: 'Habis', value: '$out', color: out > 0 ? p.danger : null)]),
              if (items.isEmpty) const EmptyNote('Belum ada barang.') else _Table(head: const ['Barang', 'Sisa', 'Status'], rows: rows, flex: const [3, 2, 2]),
            ]),
          ),
        ]);
      },
    );
  }
}
