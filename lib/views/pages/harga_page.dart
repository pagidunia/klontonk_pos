import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/harga_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HargaPage extends StatelessWidget {
  const HargaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(create: (_) => HargaViewModel(stock: deps.stock, toast: deps.toast), child: const _View());
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<HargaViewModel>();
    final tenant = context.read<AppDeps>().session.currentTenant.name;

    return PageScroll(children: [
      PageHeader(greeting: 'Harga · $tenant', title: 'Update Harga', subtitle: 'Isi atau ubah harga jual tiap barang. Daftar barang mengikuti Stok Awal.'),
      SectionCard(
        title: 'Daftar Harga',
        count: '${vm.pricedCount} dari ${vm.items.length} barang berharga',
        child: vm.items.isEmpty
            ? const EmptyNote('Belum ada barang. Tambahkan dulu di menu Stok Awal.')
            : Column(children: [
                for (final item in vm.items)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
                    child: item.id == vm.editingId ? _EditRow(item: item) : _ViewRow(item: item),
                  ),
              ]),
      ),
    ]);
  }
}

class _ViewRow extends StatelessWidget {
  const _ViewRow({required this.item});
  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text('Stok: ${formatQty(item.qty)} ${item.unit}', style: TextStyle(fontSize: 12, color: p.textSecondary))])),
      Text(item.hasPrice ? formatRupiah(item.price!) : 'Belum ada harga', style: TextStyle(fontWeight: FontWeight.w800, color: item.hasPrice ? p.text : p.textMuted)),
      IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'Edit harga ${item.name}', onPressed: () => context.read<HargaViewModel>().startEdit(item.id)),
    ]);
  }
}

class _EditRow extends StatefulWidget {
  const _EditRow({required this.item});
  final StockItem item;

  @override
  State<_EditRow> createState() => _EditRowState();
}

class _EditRowState extends State<_EditRow> {
  late final _price = TextEditingController(text: widget.item.hasPrice ? '${widget.item.price}' : '');
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final error = context.read<HargaViewModel>().save(widget.item.id, _price.text);
    if (error != null) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _price, autofocus: true, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(prefixText: 'Rp ', hintText: '0'), onSubmitted: (_) => _save())),
          const SizedBox(width: 10),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
          const SizedBox(width: 6),
          OutlinedButton(onPressed: () => context.read<HargaViewModel>().startEdit(null), child: const Text('Batal')),
        ]),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: FormError(_error)),
      ]);
}
