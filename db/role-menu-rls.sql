-- Selaraskan hak TULIS stok di database dengan pembagian menu per role.
--   kepala_cashier : boleh input stok awal & update harga (tenantnya sendiri)
--   cashier        : tidak boleh menulis stok (menu Stok Awal & Update Harga tidak ditampilkan)
-- Penjualan (checkout) dan retur memakai fungsi SECURITY DEFINER, jadi tidak terpengaruh.
-- Jalankan di Supabase SQL Editor. Satu pernyataan, atomik.
CREATE OR REPLACE FUNCTION public.is_tenant_cashier(t text) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$ SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'kepala_cashier' AND tenant_id = t) $$;
