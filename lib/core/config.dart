/// Konstanta aplikasi. Nilai per-lingkungan dibaca dari `--dart-define` saat build:
///   --dart-define=SUPABASE_URL=...  --dart-define=SUPABASE_KEY=...
///
/// Kunci publishable PUBLIK dan memang untuk dipasang di aplikasi klien: keamanan data dijaga oleh
/// RLS di database (db/schema.sql di klontonk_pos), bukan kerahasiaan kunci. JANGAN pernah mengisi
/// kunci "secret" / "service_role".
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://bxynoilzdiqjiepdewnp.supabase.co');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: 'sb_publishable_biqV-ZAK0T0B43KKyoQgSw_VOjb-GhC');

  static const appVersion = '2.0.0';

  /// Login memakai username; Supabase Auth butuh email, jadi username dipetakan ke <username>@domain ini.
  static const emailDomain = 'klontonk.local';

  /// Sesi ditutup bila tidak ada aktivitas selama ini.
  static const sessionTimeout = Duration(minutes: 30);

  /// Batas waktu satu permintaan checkout sebelum dianggap offline.
  static const checkoutTimeout = Duration(seconds: 8);

  /// Jeda percobaan ulang pengiriman antrean offline.
  static const outboxRetry = Duration(minutes: 1);

  /// Ambang "stok menipis" (Stok Total dan Beranda).
  static const lowStockMax = 5;

  static const maxQty = 1000000;
  static const maxPrice = 100000000;
  static const maxPayment = 1000000000;
}
