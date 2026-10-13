-- Parameter jatah menu per role. Aplikasi membaca tabel ini setelah login; mengubah baris di sini
-- langsung mengubah menu yang tampil, tanpa membangun ulang aplikasi.
--   role = 'kepala_cashier' | 'cashier'
--   menu = alamat rute di aplikasi, mis. '/kasir' (Transaksi), '/harga' (Update Harga)
--          atau tombol Aksi Cepat di Beranda: '/beranda/aksi/<transaksi|cek-stok|update-harga|laporan-kasir|retur>'
-- Hanya halaman sistem (Beranda, Akun, Pengaturan) yang selalu tampil untuk semua role.
-- Tabel ini SATU-SATUNYA sumber jatah menu: tidak ada jatah bawaan di kode. Role tanpa baris = menu terkelola tersembunyi.
-- Jalankan di Supabase SQL Editor sebagai SATU pernyataan DO (atomik).
DO $migrasi$
BEGIN
  CREATE TABLE IF NOT EXISTS public.role_menus (
    role text NOT NULL CHECK (role IN ('kepala_cashier', 'cashier')),
    menu text NOT NULL CHECK (menu ~ '^/[a-z0-9/_-]+$'),
    PRIMARY KEY (role, menu)
  );

  ALTER TABLE public.role_menus ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS role_menus_read ON public.role_menus;
  CREATE POLICY role_menus_read ON public.role_menus FOR SELECT TO authenticated USING (public.app_role() IS NOT NULL);
  DROP POLICY IF EXISTS role_menus_write ON public.role_menus;
  CREATE POLICY role_menus_write ON public.role_menus FOR ALL TO authenticated
    USING (public.app_role() = 'kepala_cashier') WITH CHECK (public.app_role() = 'kepala_cashier');

  -- Isi awal sesuai pembagian menu. Aman dijalankan ulang (tidak menimpa perubahan yang sudah ada).
  INSERT INTO public.role_menus (role, menu) VALUES
    ('kepala_cashier', '/stok/awal'),
    ('kepala_cashier', '/stok/keluar-laku'),
    ('kepala_cashier', '/stok/retur'),
    ('kepala_cashier', '/stok/total'),
    ('kepala_cashier', '/kasir'),
    ('kepala_cashier', '/laporan/stok-awal'),
    ('kepala_cashier', '/laporan/stok-keluar'),
    ('kepala_cashier', '/laporan/stok-retur'),
    ('kepala_cashier', '/laporan/stok-total'),
    ('kepala_cashier', '/laporan/keuangan'),
    ('kepala_cashier', '/harga'),
    ('kepala_cashier', '/catatan'),
    ('kepala_cashier', '/info-update'),
    ('kepala_cashier', '/beranda/aksi/transaksi'),
    ('kepala_cashier', '/beranda/aksi/cek-stok'),
    ('kepala_cashier', '/beranda/aksi/update-harga'),
    ('kepala_cashier', '/beranda/aksi/laporan-kasir'),
    ('kepala_cashier', '/beranda/aksi/retur'),
    ('cashier', '/stok/keluar-laku'),
    ('cashier', '/stok/total'),
    ('cashier', '/catatan'),
    ('cashier', '/info-update'),
    ('cashier', '/beranda/aksi/transaksi'),
    ('cashier', '/beranda/aksi/cek-stok'),
    ('cashier', '/beranda/aksi/laporan-kasir'),
    ('cashier', '/kasir'),
    ('cashier', '/laporan/stok-keluar'),
    ('cashier', '/laporan/stok-total')
  ON CONFLICT DO NOTHING;
END
$migrasi$;
