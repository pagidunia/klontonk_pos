import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config.dart';
import 'data/local/key_value_store.dart';
import 'data/local/local_stores.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/return_repository.dart';
import 'data/repositories/sales_repository.dart';
import 'data/repositories/stock_repository.dart';
import 'data/repositories/tenant_repository.dart';
import 'data/repositories/update_repository.dart';
import 'data/repositories/user_repository.dart';
import 'services/services.dart';
import 'viewmodels/app_deps.dart';
import 'viewmodels/data_coordinator.dart';
import 'viewmodels/returns_view_model.dart';
import 'viewmodels/sales_view_model.dart';
import 'viewmodels/session_view_model.dart';
import 'viewmodels/stock_view_model.dart';
import 'viewmodels/theme_view_model.dart';
import 'viewmodels/updates_view_model.dart';

/// Titik masuk dan "composition root": semua repository, penyimpanan lokal, dan ViewModel global dirakit di sini.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
  final db = Supabase.instance.client;

  // Klien tanpa sesi: membuat akun baru tanpa menimpa sesi admin yang sedang aktif.
  SupabaseClient detached() => SupabaseClient(AppConfig.supabaseUrl, AppConfig.supabaseKey, authOptions: const AuthClientOptions(autoRefreshToken: false));

  final KeyValueStore store = PrefsStore(await SharedPreferences.getInstance());
  final prefs = PreferencesStore(store);
  final snapshots = SnapshotStore(store);
  final outbox = OutboxStore(store);
  final toast = ToastService();

  final authRepo = AuthRepository(db, detached);
  final session = SessionViewModel(auth: authRepo, tenants: TenantRepository(db), prefs: prefs, store: store, snapshots: snapshots, toast: toast);
  final stock = StockViewModel(StockRepository(db), session, snapshots);
  final sales = SalesViewModel(repo: SalesRepository(db), auth: authRepo, session: session, stock: stock, outbox: outbox);
  final returns = ReturnsViewModel(ReturnRepository(db), session, stock, sales);
  final updates = UpdatesViewModel(UpdateRepository(db));
  final data = DataCoordinator(session: session, stock: stock, sales: sales, returns: returns, updates: updates, toast: toast);

  stock.onSaveError((message) => toast.show(message, type: ToastType.danger, duration: const Duration(seconds: 9)));
  session.addLogoutListener(data.clearAll);

  final deps = AppDeps(
    session: session,
    stock: stock,
    sales: sales,
    returns: returns,
    updates: updates,
    theme: ThemeViewModel(prefs),
    data: data,
    toast: toast,
    dialog: DialogService(),
    prefs: prefs,
    notes: NotesStore(store),
    authRepo: authRepo,
    userRepo: UserRepository(db),
  );

  await session.boot();
  runApp(KlontonkApp(deps: deps));
}
