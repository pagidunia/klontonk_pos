import '../data/local/local_stores.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/user_repository.dart';
import '../services/services.dart';
import 'data_coordinator.dart';
import 'returns_view_model.dart';
import 'sales_view_model.dart';
import 'session_view_model.dart';
import 'stock_view_model.dart';
import 'theme_view_model.dart';
import 'updates_view_model.dart';

/// Kontainer dependensi yang dirakit sekali di main() dan dibagikan lewat Provider.
class AppDeps {
  AppDeps({
    required this.session,
    required this.stock,
    required this.sales,
    required this.returns,
    required this.updates,
    required this.theme,
    required this.data,
    required this.toast,
    required this.dialog,
    required this.prefs,
    required this.notes,
    required this.authRepo,
    required this.userRepo,
  });

  final SessionViewModel session;
  final StockViewModel stock;
  final SalesViewModel sales;
  final ReturnsViewModel returns;
  final UpdatesViewModel updates;
  final ThemeViewModel theme;
  final DataCoordinator data;
  final ToastService toast;
  final DialogService dialog;
  final PreferencesStore prefs;
  final NotesStore notes;
  final AuthRepository authRepo;
  final UserRepository userRepo;
}
