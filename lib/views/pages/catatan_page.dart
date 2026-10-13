import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/local/local_stores.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/catatan_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CatatanPage extends StatelessWidget {
  const CatatanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(create: (_) => CatatanViewModel(notes: deps.notes, toast: deps.toast), child: const _View());
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await context.read<CatatanViewModel>().add(_text.text);
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<CatatanViewModel>();
    final notes = vm.notes;
    return PageScroll(children: [
      const PageHeader(greeting: 'Kasir', title: 'Catatan', subtitle: 'Catatan singkat untuk serah terima shift. Tersimpan di perangkat ini saja.'),
      SectionCard(
        title: 'Catatan baru',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _text, maxLines: 3, maxLength: NotesStore.maxLength, decoration: const InputDecoration(hintText: 'cth: Beras tinggal 2 karung, minta tambah stok.')),
          FormError(_error),
          FilledButton(onPressed: _save, child: const Text('Simpan Catatan')),
        ]),
      ),
      SectionCard(
        title: 'Daftar Catatan',
        child: notes.isEmpty
            ? const EmptyNote('Belum ada catatan.')
            : Column(children: [
                for (final n in notes)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n.text), const SizedBox(height: 4), Text(formatDateTime(n.at), style: TextStyle(fontSize: 12, color: p.textMuted))])),
                      IconButton(icon: Icon(Icons.delete_outline, color: p.danger), onPressed: () => vm.remove(n.id)),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}
