import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../data/models/models.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/info_update_view_model.dart';
import '../../viewmodels/updates_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Info Update: hanya untuk DILIHAT (perubahan terbaru & jadwal maintenance). Tidak ada tambah/ubah/hapus
/// di aplikasi.
class InfoUpdatePage extends StatelessWidget {
  const InfoUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(create: (_) => InfoUpdateViewModel(updates: deps.updates)..load(), child: const _View());
  }
}

Color _hexColor(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InfoUpdateViewModel>();

    Widget section(String kind) {
      final rows = vm.updates.list(kind);
      return SectionCard(
        title: updateKinds[kind],
        child: rows.isEmpty ? const EmptyNote('Belum ada data.') : Column(children: [for (final r in rows) _Row(row: r)]),
      );
    }

    return PageScroll(children: [
      const PageHeader(greeting: 'Versi ${AppConfig.appVersion}', title: 'Info Update', subtitle: 'Perubahan terbaru pada aplikasi dan jadwal maintenance.'),
      if (vm.loadError != null) FormError('Info belum bisa dimuat: ${vm.loadError}'),
      section('update'),
      section('maintenance'),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final AppUpdate row;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(margin: const EdgeInsets.only(top: 5, right: 12), width: 10, height: 10, decoration: BoxDecoration(color: _hexColor(row.color), shape: BoxShape.circle)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.title, style: const TextStyle(fontWeight: FontWeight.w700)), if (row.description.isNotEmpty) Text(row.description, style: TextStyle(fontSize: 12.5, color: p.textSecondary))])),
      ]),
    );
  }
}
