import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../data/models/models.dart';
import '../viewmodels/app_deps.dart';
import '../viewmodels/data_coordinator.dart';
import '../viewmodels/session_view_model.dart';
import '../viewmodels/updates_view_model.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/dialogs.dart';

class _MenuItem {
  const _MenuItem(this.path, this.label, this.desc, this.icon, {this.tenantOnly = false, this.adminOnly = false});
  final String path;
  final String label;
  final String desc;
  final IconData icon;
  final bool tenantOnly;
  final bool adminOnly;
}

const _stokMenu = [
  _MenuItem('/stok/awal', 'Stok Awal', 'Input & lihat stok awal periode', Icons.inventory_2_outlined, tenantOnly: true),
  _MenuItem('/stok/keluar-laku', 'Stok Keluar (Laku)', 'Stok keluar akibat penjualan', Icons.shopping_bag_outlined),
  _MenuItem('/stok/retur', 'Stok Retur', 'Retur pelanggan & barang rusak', Icons.assignment_return_outlined),
  _MenuItem('/stok/total', 'Stok Total', 'Sisa stok terakhir setelah transaksi', Icons.warehouse_outlined),
];

const _laporanMenu = [
  _MenuItem('/laporan/stok-awal', 'Laporan Stok Awal', 'Laporan stok awal periode', Icons.description_outlined),
  _MenuItem('/laporan/stok-keluar', 'Laporan Stok Keluar (Laku)', 'Laporan stok keluar akibat penjualan', Icons.description_outlined),
  _MenuItem('/laporan/stok-retur', 'Laporan Stok Retur', 'Laporan retur pelanggan & barang rusak', Icons.description_outlined),
  _MenuItem('/laporan/stok-total', 'Laporan Stok Total', 'Laporan sisa stok terkini', Icons.description_outlined),
  _MenuItem('/laporan/keuangan', 'Laporan Keuangan', 'Omzet, retur & arus kas (harian/bulanan/tahunan)', Icons.account_balance_wallet_outlined),
];

const _lainnyaMenu = [
  _MenuItem('/harga', 'Update Harga', 'Atur harga jual per barang', Icons.sell_outlined, tenantOnly: true),
  _MenuItem('/catatan', 'Catatan', 'Catatan serah terima shift', Icons.edit_note_outlined),
  _MenuItem('/info-update', 'Info Update', 'Perubahan terbaru & maintenance', Icons.info_outline),
  _MenuItem('/users', 'Tambah User', 'Kelola akun admin & kasir', Icons.person_add_alt_outlined, adminOnly: true),
];

/// Kerangka aplikasi: bilah atas (akun, cabang, status koneksi), laci akun, dan navigasi bawah.
/// Memuat data setelah login, memantau batas tidak-aktif, dan menampilkan sapaan sekali per login.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static String? _welcomedFor;
  Timer? _inactivity;

  AppDeps get _deps => context.read<AppDeps>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inactivity = Timer.periodic(const Duration(seconds: 10), (_) => _checkInactivity());
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootData());
  }

  Future<void> _bootData() async {
    final data = _deps.data;
    if (data.status != DataStatus.idle) return;
    final ok = await data.loadAll();
    if (!mounted) return;
    if (!ok) {
      _deps.session.expire();
      return;
    }
    await data.startSync();
    if (mounted) unawaited(_welcome());
  }

  Future<void> _checkInactivity() async {
    final closed = await _deps.session.checkInactivity();
    if (closed && mounted) {
      final nav = _deps.dialog.navigatorKey.currentContext;
      if (nav != null && nav.mounted) {
        await showConfirmDialog(nav, title: 'Sesi Berakhir', message: 'Sesi Anda telah berakhir karena tidak ada aktivitas selama ${AppConfig.sessionTimeout.inMinutes} menit. Silakan masuk kembali.', confirmText: 'OK');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInactivity();
      final deps = _deps;
      if (deps.data.status == DataStatus.ready) deps.sales.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivity?.cancel();
    super.dispose();
  }

  Future<void> _welcome() async {
    final user = _deps.session.user;
    if (user == null) return;
    final key = user.loginTime.toIso8601String();
    if (_welcomedFor == key) return;
    _welcomedFor = key;
    await _deps.updates.load(); // gagal -> tetap pakai isi terakhir / bawaan
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (_) => _WelcomeDialog(name: user.name, tenant: _deps.session.currentTenant.name, updates: _deps.updates));
  }

  int get _tab {
    final l = widget.location;
    if (l == '/' || l == '/beranda') return 0;
    if (l.startsWith('/stok')) return 1;
    if (l.startsWith('/kasir')) return 2;
    if (l.startsWith('/laporan')) return 3;
    return -1;
  }

  Future<void> _openMenu(String title, List<_MenuItem> items) async {
    final session = _deps.session;
    final visible = items.where((i) => (!i.tenantOnly || session.canEditStock) && (!i.adminOnly || session.isAdmin)).toList();
    final picked = await showModalBottomSheet<_MenuItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final item in visible)
            ListTile(
              leading: CircleAvatar(backgroundColor: context.pal.primarySoft, child: Icon(item.icon, color: context.pal.primary, size: 20)),
              title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(item.desc),
              onTap: () => Navigator.pop(context, item),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked != null && mounted) context.go(picked.path);
  }

  void _onTab(int index) {
    switch (index) {
      case 0:
        context.go('/beranda');
      case 1:
        _openMenu('Menu Stok', _stokMenu);
      case 2:
        context.go('/kasir');
      case 3:
        _openMenu('Menu Laporan', _laporanMenu);
      case 4:
        _openMenu('Lainnya', _lainnyaMenu);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final session = context.watch<SessionViewModel>();
    final data = context.watch<DataCoordinator>();
    final user = session.user;
    final pending = context.select<AppDeps, int>((d) => d.sales.outboxState.pending);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (context) => Padding(padding: const EdgeInsets.all(8), child: GestureDetector(onTap: () => Scaffold.of(context).openDrawer(), child: CircleAvatar(backgroundColor: p.primary, child: Text(user?.avatar ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))))),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.storefront_outlined, size: 16, color: p.primary), const SizedBox(width: 6), Flexible(child: Text(session.currentTenant.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.primary)))]),
        ),
        centerTitle: false,
        actions: [
          if (!data.online) Padding(padding: const EdgeInsets.only(right: 4), child: Tooltip(message: 'Offline', child: Icon(Icons.cloud_off_outlined, color: p.warning))),
          if (pending > 0) Padding(padding: const EdgeInsets.only(right: 12), child: Pill('$pending antre', color: p.warning)),
        ],
      ),
      drawer: _AccountDrawer(onNavigate: (path) {
        Navigator.of(context).pop();
        context.go(path);
      }),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => session.touch(),
        child: data.status == DataStatus.ready ? widget.child : const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab < 0 ? 4 : _tab,
        onDestinationSelected: _onTab,
        backgroundColor: p.surface,
        indicatorColor: p.primarySoft,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Stok'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Transaksi'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Laporan'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Lainnya'),
        ],
      ),
    );
  }
}

class _AccountDrawer extends StatelessWidget {
  const _AccountDrawer({required this.onNavigate});
  final void Function(String path) onNavigate;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final deps = context.read<AppDeps>();
    final session = context.watch<SessionViewModel>();
    final data = context.watch<DataCoordinator>();
    final user = session.user;

    Future<void> logout() async {
      final yakin = await deps.dialog.confirm(title: 'Konfirmasi Keluar', message: 'Apakah Anda yakin ingin logout dari sistem?', confirmText: 'Ya, Keluar', cancelText: 'Batal', danger: true);
      if (!yakin) return;
      await session.logout();
    }

    return Drawer(
      child: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: p.primary,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 26, backgroundColor: Colors.white, child: Text(user?.avatar ?? '?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.primary))),
              const SizedBox(height: 12),
              Text(user?.name ?? '-', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Text('${user?.isAdmin == true ? 'Admin' : 'Kasir'} · ${session.currentTenant.name}', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          ListTile(leading: const Icon(Icons.person_outline), title: const Text('Informasi Akun'), subtitle: Text('@${user?.username ?? ''}'), onTap: () => onNavigate('/akun')),
          ListTile(leading: Icon(data.online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, color: data.online ? p.success : p.warning), title: const Text('Koneksi'), subtitle: Text(data.online ? 'Terhubung ke internet' : 'Offline — penjualan disimpan di perangkat')),
          const Spacer(),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Pengaturan'), subtitle: const Text('Tema & preferensi'), onTap: () => onNavigate('/pengaturan')),
          ListTile(leading: Icon(Icons.logout, color: p.danger), title: Text('Logout', style: TextStyle(color: p.danger, fontWeight: FontWeight.w700)), onTap: logout),
          ListTile(leading: const Icon(Icons.info_outline), title: const Text('Versi Aplikasi'), subtitle: Text('v${AppConfig.appVersion} · Multi-Tenant')),
        ]),
      ),
    );
  }
}

class _WelcomeDialog extends StatelessWidget {
  const _WelcomeDialog({required this.name, required this.tenant, required this.updates});
  final String name;
  final String tenant;
  final UpdatesViewModel updates;

  Color _color(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

  Widget _section(BuildContext context, String title, List<AppUpdate> rows) {
    final p = context.pal;
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: p.textMuted, letterSpacing: 0.6))),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(margin: const EdgeInsets.only(top: 5, right: 10), width: 9, height: 9, decoration: BoxDecoration(color: _color(r.color), shape: BoxShape.circle)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)), if (r.description.isNotEmpty) Text(r.description, style: TextStyle(fontSize: 12.5, color: p.textSecondary))])),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${sapaanText()}, $name'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Cabang aktif: $tenant', style: TextStyle(color: context.pal.textSecondary)),
            _section(context, updateKinds['update']!, updates.list('update')),
            _section(context, updateKinds['maintenance']!, updates.list('maintenance')),
          ]),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Mulai'))],
      );

  String sapaanText() {
    final jam = DateTime.now().hour;
    return jam < 11 ? 'Selamat Pagi' : (jam < 15 ? 'Selamat Siang' : (jam < 18 ? 'Selamat Sore' : 'Selamat Malam'));
  }
}
