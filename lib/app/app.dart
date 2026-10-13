import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/app_deps.dart';
import '../viewmodels/session_view_model.dart';
import '../viewmodels/theme_view_model.dart';
import '../views/app_shell.dart';
import '../views/pages/akun_pages.dart';
import '../views/pages/catatan_page.dart';
import '../views/pages/harga_page.dart';
import '../views/pages/home_page.dart';
import '../views/pages/info_update_page.dart';
import '../views/pages/kasir_page.dart';
import '../views/pages/keuangan_page.dart';
import '../views/pages/laporan_pages.dart';
import '../views/pages/login_page.dart';
import '../views/pages/status_pages.dart';
import '../views/pages/stok_awal_page.dart';
import '../views/pages/stok_keluar_page.dart';
import '../views/pages/stok_retur_page.dart';
import '../views/pages/stok_total_page.dart';
import '../views/pages/users_page.dart';
import '../views/theme.dart';

class KlontonkApp extends StatefulWidget {
  const KlontonkApp({super.key, required this.deps});
  final AppDeps deps;

  @override
  State<KlontonkApp> createState() => _KlontonkAppState();
}

class _KlontonkAppState extends State<KlontonkApp> {
  late final GoRouter _router = _buildRouter();

  GoRouter _buildRouter() {
    final deps = widget.deps;
    final session = deps.session;

    Page<void> page(GoRouterState state, Widget child) => NoTransitionPage<void>(key: state.pageKey, child: child);

    // Guard: halaman admin ditolak untuk non-admin; input stok/harga hanya untuk akun tenant.
    Widget adminOnly(Widget child) => session.isAdmin ? child : const ForbiddenPage();
    Widget tenantOnly(Widget child) => session.canEditStock ? child : const ForbiddenPage.tenantOnly();

    GoRoute route(String path, Widget Function() build) => GoRoute(path: path, pageBuilder: (c, s) => page(s, build()));

    return GoRouter(
      navigatorKey: deps.dialog.navigatorKey,
      initialLocation: '/beranda',
      refreshListenable: session,
      redirect: (context, state) {
        final masuk = session.status == AuthStatus.authenticated;
        final path = state.uri.path;
        if (!masuk) return path == '/login' ? null : '/login';
        if (path == '/login' || path == '/') return '/beranda';
        return null;
      },
      errorBuilder: (context, state) => Scaffold(body: SafeArea(child: const NotFoundPage())),
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        ShellRoute(
          builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
          routes: [
            route('/beranda', () => const HomePage()),
            route('/kasir', () => const KasirPage()),
            route('/akun', () => const AkunPage()),
            route('/pengaturan', () => const PengaturanPage()),
            route('/stok/awal', () => tenantOnly(const StokAwalPage())),
            route('/stok/keluar-laku', () => const StokKeluarPage()),
            route('/stok/retur', () => const StokReturPage()),
            route('/stok/total', () => const StokTotalPage()),
            route('/info-update', () => const InfoUpdatePage()),
            route('/catatan', () => const CatatanPage()),
            route('/harga', () => tenantOnly(const HargaPage())),
            route('/laporan/stok-awal', () => const LaporanStokAwalPage()),
            route('/laporan/stok-keluar', () => const LaporanStokKeluarPage()),
            route('/laporan/stok-retur', () => const LaporanStokReturPage()),
            route('/laporan/stok-total', () => const LaporanStokTotalPage()),
            route('/laporan/keuangan', () => const KeuanganPage()),
            route('/users', () => adminOnly(const UsersPage())),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    return MultiProvider(
      providers: [
        Provider<AppDeps>.value(value: deps),
        ChangeNotifierProvider.value(value: deps.session),
        ChangeNotifierProvider.value(value: deps.data),
        ChangeNotifierProvider.value(value: deps.theme),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, theme, _) => MaterialApp.router(
          title: 'Klontonk POS',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: theme.mode,
          routerConfig: _router,
          scaffoldMessengerKey: deps.toast.messengerKey,
        ),
      ),
    );
  }
}
