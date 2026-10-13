-- Tambah parameter tombol "Aksi Cepat" di Beranda ke tabel role_menus (tabel sudah dibuat oleh role-menus.sql).
--   cashier        : Transaksi, Cek Stok, Laporan Kasir
--   kepala_cashier : Transaksi, Cek Stok, Update Harga, Laporan Kasir, Retur Barang
-- Aman dijalankan ulang. Jalankan di Supabase SQL Editor sebagai SATU pernyataan DO (atomik).
DO $migrasi$
BEGIN
  INSERT INTO public.role_menus (role, menu) VALUES
    ('kepala_cashier', '/beranda/aksi/transaksi'),
    ('kepala_cashier', '/beranda/aksi/cek-stok'),
    ('kepala_cashier', '/beranda/aksi/update-harga'),
    ('kepala_cashier', '/beranda/aksi/laporan-kasir'),
    ('kepala_cashier', '/beranda/aksi/retur'),
    ('cashier', '/beranda/aksi/transaksi'),
    ('cashier', '/beranda/aksi/cek-stok'),
    ('cashier', '/beranda/aksi/laporan-kasir')
  ON CONFLICT DO NOTHING;
END
$migrasi$;
