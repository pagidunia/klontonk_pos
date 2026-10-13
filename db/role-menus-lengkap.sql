-- Rapikan parameter menu di tabel role_menus (satu pernyataan DO, atomik, aman dijalankan ulang):
--   1) Hapus "Tambah User" (/users) dari semua role.
--   2) Daftarkan Catatan (/catatan) dan Info Update (/info-update, hanya lihat) untuk kedua role,
--      karena sekarang kedua menu itu juga diatur oleh tabel ini.
-- Menu yang barisnya tidak ada untuk sebuah role TIDAK ditampilkan di aplikasi.
DO $migrasi$
BEGIN
  DELETE FROM public.role_menus WHERE menu = '/users';

  INSERT INTO public.role_menus (role, menu) VALUES
    ('kepala_cashier', '/catatan'),
    ('kepala_cashier', '/info-update'),
    ('cashier', '/catatan'),
    ('cashier', '/info-update')
  ON CONFLICT DO NOTHING;
END
$migrasi$;
