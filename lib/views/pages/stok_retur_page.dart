import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/retur_view_model.dart';
import '../../viewmodels/returns_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StokReturPage extends StatelessWidget {
  const StokReturPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(create: (_) => ReturViewModel(returns: deps.returns, stock: deps.stock, toast: deps.toast), child: const _View());
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _qty = TextEditingController();
  final _note = TextEditingController();
  String? _itemId;
  String? _reason;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(ReturViewModel vm) async {
    final error = await vm.submit(itemId: _itemId, qtyText: _qty.text, reason: _reason ?? vm.reasons.first.value, note: _note.text);
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) {
        _qty.clear();
        _note.clear();
        _itemId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<ReturViewModel>();
    final tenant = context.read<AppDeps>().session.currentTenant.name;
    final stats = vm.monthStats;
    final opts = vm.options();
    final reasons = vm.reasons;
    final reasonValue = reasons.any((r) => r.value == _reason) ? _reason : reasons.first.value;

    return PageScroll(children: [
      PageHeader(greeting: 'Stok · $tenant', title: 'Stok Retur', subtitle: 'Proses barang yang dikembalikan pelanggan atau dikeluarkan karena rusak.'),
      StatGrid(children: [
        StatBox(label: 'Retur pelanggan', value: '${stats.customerCount}', sub: 'bulan ini'),
        StatBox(label: 'Retur supplier', value: '${stats.supplierCount}', sub: 'bulan ini'),
        StatBox(label: 'Uang dikembalikan bulan ini', value: formatRupiah(stats.refund)),
      ]),
      SectionCard(
        title: 'Proses Retur',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentTabs<String>(value: vm.kind, options: {for (final k in returnKinds) k.id: k.label}, onChanged: (k) => setState(() {
                vm.setKind(k);
                _itemId = null;
                _reason = null;
                _error = null;
              })),
          const SizedBox(height: 10),
          Text(vm.hint, style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _itemId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Barang'),
            hint: const Text('Pilih barang…'),
            items: [for (final o in opts) DropdownMenuItem(value: o.item.id, enabled: o.usable, child: Text('${o.item.name} — ${o.detail}', overflow: TextOverflow.ellipsis, style: TextStyle(color: o.usable ? null : p.textMuted)))],
            onChanged: (v) => setState(() => _itemId = v),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah'))),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(initialValue: reasonValue, isExpanded: true, decoration: const InputDecoration(labelText: 'Alasan'), items: [for (final r in reasons) DropdownMenuItem(value: r.value, child: Text(r.label, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => _reason = v))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _note, maxLength: maxReturnNote, decoration: const InputDecoration(labelText: 'Catatan (opsional)', hintText: 'cth: kemasan sobek', counterText: '')),
          const SizedBox(height: 12),
          FormError(_error),
          FilledButton(onPressed: vm.busy ? null : () => _submit(vm), child: Text(vm.busy ? 'Memproses…' : 'Proses Retur')),
        ]),
      ),
      SectionCard(
        title: 'Riwayat Retur',
        count: '${vm.history.length} terakhir',
        child: vm.history.isEmpty ? const EmptyNote('Belum ada retur di tenant ini.') : Column(children: [for (final r in vm.history) _HistoryRow(ret: r)]),
      ),
    ]);
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.ret});
  final StockReturn ret;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final customer = ret.kind == 'pelanggan';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ret.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${formatWhen(ret.at)} · ${reasonLabel(ret.reason)}${(ret.note ?? '').isEmpty ? '' : ' · “${ret.note}”'}', style: TextStyle(fontSize: 12, color: p.textSecondary)),
            Text('${ret.no} · ${ret.cashier}', style: TextStyle(fontSize: 12, color: p.textMuted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Pill(customer ? 'Pelanggan' : 'Supplier', color: customer ? p.warning : p.info),
          const SizedBox(height: 4),
          Text('${customer ? '+' : '−'}${formatQty(ret.qty)} ${ret.unit}', style: const TextStyle(fontWeight: FontWeight.w800)),
          if (customer) Text(formatRupiah(ret.amount), style: TextStyle(fontSize: 12, color: p.textSecondary)),
        ]),
      ]),
    );
  }
}
