import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../domain/stock_rules.dart';
import '../../services/services.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/stok_awal_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/scanner_page.dart';

class StokAwalPage extends StatelessWidget {
  const StokAwalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(
      create: (_) => StokAwalViewModel(stock: deps.stock, dialog: deps.dialog, toast: deps.toast),
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _barcode = TextEditingController();
  final _name = TextEditingController();
  final _qty = TextEditingController();
  String _unit = units.first;
  String? _error;

  @override
  void dispose() {
    _barcode.dispose();
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _fill(StockItem? item) {
    _barcode.text = item?.barcode ?? '';
    _name.text = item?.name ?? '';
    _qty.text = item == null ? '' : '${item.qty}';
    _unit = item?.unit ?? units.first;
    _error = null;
  }

  void _edit(StockItem? item) {
    context.read<StokAwalViewModel>().startEdit(item);
    setState(() => _fill(item));
  }

  Future<void> _scan() async {
    final vm = context.read<StokAwalViewModel>();
    final toast = context.read<AppDeps>().toast;
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    setState(() {
      _barcode.text = code;
      _error = null;
    });
    final owner = vm.stock.findByBarcode(code);
    if (owner != null && owner.id != vm.editingId) {
      toast.show('Barcode ini sudah dipakai: ${owner.name}', type: ToastType.warning);
    } else {
      toast.show('Barcode terbaca: $code', type: ToastType.success);
    }
  }

  void _save() {
    final vm = context.read<StokAwalViewModel>();
    final error = vm.save(name: _name.text, qty: _qty.text, unit: _unit, barcode: _barcode.text);
    setState(() {
      _error = error;
      if (error == null) _fill(null);
    });
  }

  Future<void> _import() async {
    final vm = context.read<StokAwalViewModel>();
    final toast = context.read<AppDeps>().toast;
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['csv', 'txt'], withData: true);
    final file = picked?.files.firstOrNull;
    if (file == null) return;
    if (file.size > 1024 * 1024) {
      toast.show('Berkas terlalu besar (maksimal 1 MB).', type: ToastType.danger);
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      toast.show('Berkas tidak bisa dibaca.', type: ToastType.danger);
      return;
    }
    await vm.importCsv(file.name, _decode(bytes));
  }

  String _decode(List<int> bytes) {
    try {
      return const Utf8Decoder().convert(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<StokAwalViewModel>();
    final tenant = context.read<AppDeps>().session.currentTenant.name;
    final editing = vm.editingId != null;

    return PageScroll(children: [
      PageHeader(greeting: 'Stok · $tenant', title: 'Stok Awal', subtitle: 'Kelola daftar barang dan jumlah stok awal periode untuk tenant ini.'),
      SectionCard(
        title: editing ? 'Edit Stok' : 'Tambah Stok',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: TextField(controller: _barcode, autocorrect: false, maxLength: 40, decoration: const InputDecoration(labelText: 'Barcode (opsional)', counterText: ''))),
            const SizedBox(width: 10),
            SizedBox(height: 52, child: OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan'))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _name, maxLength: 60, decoration: const InputDecoration(labelText: 'Nama Barang', hintText: 'cth: Beras Lahap', counterText: '')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah Stok'))),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(initialValue: _unit, decoration: const InputDecoration(labelText: 'Satuan'), items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u))], onChanged: (v) => setState(() => _unit = v ?? units.first))),
          ]),
          const SizedBox(height: 12),
          FormError(_error),
          Row(children: [
            Expanded(child: FilledButton(onPressed: _save, child: Text(editing ? 'Simpan Perubahan' : 'Simpan'))),
            if (editing) ...[const SizedBox(width: 10), OutlinedButton(onPressed: () => _edit(null), child: const Text('Batal'))],
          ]),
        ]),
      ),
      SectionCard(
        title: 'Daftar Barang',
        count: '${vm.items.length} barang',
        trailing: TextButton.icon(onPressed: _import, icon: const Icon(Icons.upload_file_outlined, size: 18), label: const Text('Impor CSV')),
        child: vm.items.isEmpty
            ? const EmptyNote('Belum ada stok. Isi form di atas untuk menambah barang.')
            : Column(children: [
                for (final item in vm.items)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border)), color: item.id == vm.editingId ? p.primarySoft : null),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text('Satuan: ${item.unit}${item.barcode == null ? '' : ' · ${item.barcode}'}', style: TextStyle(fontSize: 12, color: p.textSecondary))])),
                      Text('${formatQty(item.qty)} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'Edit ${item.name}', onPressed: () => _edit(item)),
                      IconButton(icon: Icon(Icons.delete_outline, size: 20, color: p.danger), tooltip: 'Hapus ${item.name}', onPressed: () => vm.delete(item)),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}
