# Klontonk POS (Flutter mobile)

Aplikasi kasir (Point of Sales) untuk warung multi-cabang, versi **Flutter mobile** (Android dan iOS) dengan pola **MVVM**. Memakai Supabase yang sama dengan versi web (tag `pwa-version`): database, login, dan aturan RLS tidak berubah.

## Fitur

- **Kasir**: cari barang atau scan barcode (kamera), keranjang, pembayaran tunai atau QRIS/transfer, struk 58 mm lewat dialog cetak sistem.
- **Stok**: stok awal, stok total, retur (pelanggan dan supplier), update harga, impor stok dari CSV.
- **Laporan**: stok awal, stok keluar, retur, stok total, dan keuangan (harian/bulanan/tahunan atau rentang tanggal).
- **Multi-tenant**: kasir hanya melihat cabangnya; admin melihat semua dan mengelola akun.
- **Offline**: penjualan disimpan di perangkat lalu dikirim otomatis saat internet kembali (client_id mencegah ganda).
- Catatan kasir, info update, tema terang/gelap, sesi otomatis berakhir setelah 30 menit tidak aktif.

Belum ada: notifikasi push (versi web memakai Web Push; versi mobile membutuhkan FCM).

## Arsitektur MVVM

```
lib/
├── main.dart          composition root: merakit repository, penyimpanan lokal, ViewModel
├── app/               MaterialApp.router, GoRouter (redirect login, guard admin/tenant)
├── core/              config, format, kalender, Result<T>/AppError
├── data/
│   ├── models/        Model
│   ├── local/         penyimpanan lokal: antrean offline, snapshot stok, catatan, preferensi
│   └── repositories/  akses Supabase (mengembalikan Result<T>, tidak pernah melempar)
├── domain/            logika murni: keranjang, antrean/sinkron, laporan, keuangan, impor CSV
├── services/          Toast, Dialog, pencetak struk
├── viewmodels/        ViewModel (ChangeNotifier): session, stok, penjualan, retur, tiap halaman
└── views/             View: tema, kerangka (navigasi bawah), halaman, widget bersama
```

Aliran: `View` -> `ViewModel` -> `Repository` -> Supabase. Keamanan data dijaga RLS di database, bukan oleh aplikasi.

## Menjalankan

```bash
flutter pub get
flutter run                      # perangkat/emulator tersambung
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
flutter test
flutter analyze
```

Konfigurasi opsional lewat `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...` (kunci **publishable** saja; jangan pernah memakai kunci secret / service_role). Tanpa itu dipakai project Supabase bawaan di `lib/core/config.dart`.

Catatan: build Android butuh Android SDK 36; build iOS butuh Xcode lengkap dan akun Apple Developer untuk penandatanganan. APK rilis saat ini ditandatangani kunci debug (cukup untuk uji, belum untuk Play Store).

## Basis data

Skema dan fungsi (`checkout`, `process_return`, `delete_app_user`) ada di `db/schema.sql` pada versi web (tag `pwa-version`).
