/// Hak akses menu per role.
///
/// JATAH per role HANYA dari tabel `role_menus` di Supabase (kolom role, menu; `menu` = alamat rute atau
/// kunci tombol Aksi Cepat). Tidak ada jatah yang tertanam di kode. Setelah login jatah dimuat
/// (SessionViewModel.loadMenus) dan salinan terakhirnya disimpan di perangkat untuk saat offline.
///
/// Yang ada di kode hanya KATALOG menu di bawah: daftar fitur yang diatur lewat tabel. Menu di
/// katalog yang tidak ada barisnya untuk role akun = tidak ditampilkan dan tidak bisa dibuka lewat rute.
/// (Keamanan data sesungguhnya tetap dijaga RLS di database.)
const roleKepalaCashier = 'kepala_cashier';
const roleCashier = 'cashier';

/// Kunci tombol "Aksi Cepat" di Beranda (bukan rute; awalan khusus di kolom `menu`).
const awalanAksiCepat = '/beranda/aksi/';

/// Katalog menu yang diatur lewat tabel role_menus. Hanya halaman sistem (Beranda, Akun, Pengaturan)
/// yang selalu terbuka untuk semua role yang login.
const menuTerkelola = <String>{
  '/stok/awal',
  '/stok/keluar-laku',
  '/stok/retur',
  '/stok/total',
  '/kasir', // Transaksi
  '/kasir/utang', // Metode bayar Utang di Transaksi
  '/laporan/stok-awal',
  '/laporan/stok-keluar',
  '/laporan/stok-retur',
  '/laporan/stok-total',
  '/laporan/keuangan',
  '/harga', // Update Harga
  '/catatan', // Catatan
  '/info-update', // Info Update (hanya lihat)
  '/users', // Tambah User
  '${awalanAksiCepat}transaksi',
  '${awalanAksiCepat}cek-stok',
  '${awalanAksiCepat}update-harga',
  '${awalanAksiCepat}laporan-kasir',
  '${awalanAksiCepat}retur',
};

/// Boleh membuka [path]? [menuDb] = jatah role ini dari Supabase; null = belum termuat -> menu di
/// katalog tidak ditampilkan (aman).
bool canOpen(String? role, String path, {Set<String>? menuDb}) {
  if (role == null) return false;
  if (!menuTerkelola.contains(path)) return true;
  return menuDb?.contains(path) ?? false;
}
