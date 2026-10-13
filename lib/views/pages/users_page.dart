import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/app_deps.dart';
import '../../viewmodels/users_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(
      create: (_) => UsersViewModel(repo: deps.userRepo, auth: deps.authRepo, session: deps.session, toast: deps.toast, confirm: ({required title, required message}) => deps.dialog.confirm(title: title, message: message, confirmText: 'Ya, Hapus', cancelText: 'Batal', danger: true))..load(),
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
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _role = 'cashier';
  String? _tenant;
  String? _error;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(String defaultTenant) async {
    final vm = context.read<UsersViewModel>();
    final error = await vm.create(username: _username.text, password: _password.text, name: _name.text, role: _role, tenant: _tenant ?? defaultTenant);
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) {
      _name.clear();
      _username.clear();
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<UsersViewModel>();
    final tenants = vm.session.tenants;
    final tenant = tenants.any((t) => t.id == _tenant) ? _tenant! : tenants.first.id;
    final strength = passwordStrength(_password.text);
    final strengthColor = [p.border, p.danger, p.warning, p.info, p.success][strength];

    return PageScroll(children: [
      const PageHeader(greeting: 'Manajemen Akun', title: 'Tambah User', subtitle: 'Buat akun baru untuk admin atau kasir. Password dikelola Supabase Auth dan tidak pernah disimpan di aplikasi.'),
      SectionCard(
        title: 'Buat Akun Baru',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _name, maxLength: 60, decoration: const InputDecoration(labelText: 'Nama Lengkap', hintText: 'cth: Kasir Warung Biru', counterText: '')),
          const SizedBox(height: 12),
          TextField(controller: _username, maxLength: 24, autocorrect: false, decoration: const InputDecoration(labelText: 'Username', helperText: '3–24 karakter: huruf kecil, angka, titik, underscore.', counterText: '')),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _hide,
            maxLength: 128,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: 'Password', helperText: 'Minimal 8 karakter, huruf + angka.', counterText: '', suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide))),
          ),
          const SizedBox(height: 8),
          Row(children: [for (var i = 1; i <= 4; i++) Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 5, decoration: BoxDecoration(color: i <= strength ? strengthColor : p.border, borderRadius: BorderRadius.circular(3))))]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(initialValue: _role, decoration: const InputDecoration(labelText: 'Role'), items: const [DropdownMenuItem(value: 'cashier', child: Text('Kasir')), DropdownMenuItem(value: 'admin', child: Text('Admin'))], onChanged: (v) => setState(() => _role = v ?? 'cashier'))),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(initialValue: tenant, isExpanded: true, decoration: const InputDecoration(labelText: 'Cabang'), items: [for (final t in tenants) DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => _tenant = v))),
          ]),
          const SizedBox(height: 14),
          FormError(_error),
          FilledButton(onPressed: vm.saving ? null : () => _submit(tenants.first.id), child: Text(vm.saving ? 'Menyimpan…' : 'Simpan User')),
        ]),
      ),
      SectionCard(
        title: 'User Terdaftar',
        child: vm.loading
            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            : vm.loadError != null
                ? FormError(vm.loadError)
                : vm.users.isEmpty
                    ? const EmptyNote('Belum ada user.')
                    : Column(children: [
                        for (final u in vm.users)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
                            child: Row(children: [
                              CircleAvatar(backgroundColor: p.primarySoft, child: Text(u.avatar.isEmpty ? '?' : u.avatar, style: TextStyle(color: p.primary, fontWeight: FontWeight.w800))),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text('@${u.username} · ${tenants.where((t) => t.id == u.tenantId).map((t) => t.name).firstOrNull ?? u.tenantId}', style: TextStyle(fontSize: 12, color: p.textSecondary))])),
                              Pill(u.role == 'admin' ? 'Admin' : 'Kasir', color: u.role == 'admin' ? p.primary : p.textMuted),
                              IconButton(icon: Icon(Icons.delete_outline, color: p.danger), onPressed: u.id == vm.session.user?.id ? null : () => vm.delete(u)),
                            ]),
                          ),
                      ]),
      ),
    ]);
  }
}
