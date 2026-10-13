import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../data/models/models.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/info_update_view_model.dart';
import '../../viewmodels/updates_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

class InfoUpdatePage extends StatelessWidget {
  const InfoUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(
      create: (_) => InfoUpdateViewModel(updates: deps.updates, session: deps.session, toast: deps.toast, confirm: ({required title, required message}) => deps.dialog.confirm(title: title, message: message, confirmText: 'Ya, Hapus', cancelText: 'Batal', danger: true))..load(),
      child: const _View(),
    );
  }
}

Color _hexColor(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _kind = 'update';
  String _color = updateColors.first.value;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _fill(AppUpdate? row) {
    _title.text = row?.title ?? '';
    _desc.text = row?.description ?? '';
    _kind = row?.kind ?? 'update';
    _color = row?.color ?? updateColors.first.value;
    _error = null;
  }

  Future<void> _save() async {
    final vm = context.read<InfoUpdateViewModel>();
    final error = await vm.save(kind: _kind, title: _title.text, description: _desc.text, color: _color);
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _fill(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<InfoUpdateViewModel>();
    final admin = vm.isAdmin;
    final editing = vm.editingId != null;

    Widget section(String kind) {
      final rows = vm.updates.list(kind);
      return SectionCard(
        title: updateKinds[kind],
        child: rows.isEmpty
            ? const EmptyNote('Belum ada data.')
            : Column(children: [
                for (final r in rows)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    color: r.id == vm.editingId ? p.primarySoft : null,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(margin: const EdgeInsets.only(top: 5, right: 12), width: 10, height: 10, decoration: BoxDecoration(color: _hexColor(r.color), shape: BoxShape.circle)),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)), if (r.description.isNotEmpty) Text(r.description, style: TextStyle(fontSize: 12.5, color: p.textSecondary))])),
                      if (admin) ...[
                        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit_outlined, size: 19), onPressed: () => setState(() {
                              vm.startEdit(r.id);
                              _fill(r);
                            })),
                        IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.delete_outline, size: 19, color: p.danger), onPressed: () => vm.remove(r)),
                      ],
                    ]),
                  ),
              ]),
      );
    }

    return PageScroll(children: [
      PageHeader(greeting: 'Versi ${AppConfig.appVersion}', title: 'Info Update', subtitle: admin ? 'Ubah info yang tampil di popup sapaan dan halaman ini.' : 'Perubahan terbaru pada aplikasi dan jadwal maintenance.'),
      if (vm.loadError != null) FormError('Info belum bisa dimuat: ${vm.loadError}'),
      section('update'),
      section('maintenance'),
      if (admin)
        SectionCard(
          title: editing ? 'Edit Info' : 'Tambah Info',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(initialValue: _kind, decoration: const InputDecoration(labelText: 'Jenis'), items: [for (final e in updateKinds.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => _kind = v ?? 'update'))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(initialValue: _color, decoration: const InputDecoration(labelText: 'Warna'), items: [for (final c in updateColors) DropdownMenuItem(value: c.value, child: Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: _hexColor(c.value), shape: BoxShape.circle)), const SizedBox(width: 8), Text(c.label)]))], onChanged: (v) => setState(() => _color = v ?? updateColors.first.value))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _title, maxLength: 80, decoration: const InputDecoration(labelText: 'Judul', counterText: '')),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 3, maxLength: 300, decoration: const InputDecoration(labelText: 'Deskripsi (opsional)')),
            FormError(_error),
            Row(children: [
              Expanded(child: FilledButton(onPressed: _save, child: const Text('Simpan'))),
              if (editing) ...[const SizedBox(width: 10), OutlinedButton(onPressed: () => setState(() {
                    vm.startEdit(null);
                    _fill(null);
                  }), child: const Text('Batal'))],
            ]),
          ]),
        ),
    ]);
  }
}
