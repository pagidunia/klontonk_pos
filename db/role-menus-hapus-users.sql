-- Sembunyikan menu "Tambah User" dari kepala_cashier (menu ini tidak ada di jatah role mana pun).
-- Jalankan di Supabase SQL Editor. Aman dijalankan ulang.
-- Untuk mengaktifkannya lagi kelak: INSERT INTO public.role_menus (role, menu) VALUES ('kepala_cashier', '/users');
DELETE FROM public.role_menus WHERE menu = '/users';
