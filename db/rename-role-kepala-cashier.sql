-- Ganti nilai role 'admin' menjadi 'kepala_cashier' di seluruh aturan database.
-- Jalankan SEKALI di Supabase SQL Editor. Seluruhnya satu pernyataan DO, jadi atomik (semua berhasil atau semua batal)
-- walaupun klien SQL Anda menjalankan skrip per pernyataan / auto-commit.
-- URUTAN: jalankan ini DULU, baru pasang aplikasi versi baru. Aplikasi lama (web/APK sebelumnya)
-- memakai 'admin', jadi akun yang diubah akan diperlakukan sebagai kasir sampai aplikasinya diperbarui.
DO $migrasi$
BEGIN

-- 1) Lepas aturan lama
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.push_subscriptions DROP CONSTRAINT IF EXISTS push_subscriptions_role_check;

-- 2) Ubah data yang ada
UPDATE public.profiles SET role = 'kepala_cashier' WHERE role = 'admin';
UPDATE public.push_subscriptions SET role = 'kepala_cashier' WHERE role = 'admin';

-- 3) Pasang aturan baru
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('kepala_cashier', 'cashier'));
ALTER TABLE public.push_subscriptions ADD CONSTRAINT push_subscriptions_role_check CHECK (role IN ('kepala_cashier', 'cashier'));

-- 4) Fungsi yang memeriksa peran
CREATE OR REPLACE FUNCTION public.can_access_tenant(t text) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$ SELECT COALESCE((SELECT role = 'kepala_cashier' OR tenant_id = t FROM public.profiles WHERE id = auth.uid()), false) $$;

CREATE OR REPLACE FUNCTION public.delete_app_user(p_username text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_target public.profiles%ROWTYPE;
BEGIN
  IF public.app_role() IS DISTINCT FROM 'kepala_cashier' THEN
    RAISE EXCEPTION 'Akses ditolak. Fitur ini hanya untuk Kepala Cashier.' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_target FROM public.profiles WHERE username = lower(btrim(p_username));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User tidak ditemukan.' USING ERRCODE = 'P0001';
  END IF;
  IF v_target.id = auth.uid() THEN
    RAISE EXCEPTION 'Tidak bisa menghapus akun Anda sendiri.' USING ERRCODE = 'P0001';
  END IF;
  IF v_target.role = 'kepala_cashier' AND (SELECT count(*) FROM public.profiles WHERE role = 'kepala_cashier') <= 1 THEN
    RAISE EXCEPTION 'Minimal harus ada satu Kepala Cashier.' USING ERRCODE = 'P0001';
  END IF;
  DELETE FROM auth.users WHERE id = v_target.id;
END;
$$;

-- 5) Kebijakan RLS
DROP POLICY IF EXISTS updates_admin_insert ON public.app_updates;
CREATE POLICY updates_admin_insert ON public.app_updates FOR INSERT TO authenticated WITH CHECK (public.app_role() = 'kepala_cashier');
DROP POLICY IF EXISTS updates_admin_update ON public.app_updates;
CREATE POLICY updates_admin_update ON public.app_updates FOR UPDATE TO authenticated
  USING (public.app_role() = 'kepala_cashier') WITH CHECK (public.app_role() = 'kepala_cashier');
DROP POLICY IF EXISTS updates_admin_delete ON public.app_updates;
CREATE POLICY updates_admin_delete ON public.app_updates FOR DELETE TO authenticated USING (public.app_role() = 'kepala_cashier');

DROP POLICY IF EXISTS profiles_read ON public.profiles;
CREATE POLICY profiles_read ON public.profiles FOR SELECT TO authenticated
  USING (id = auth.uid() OR public.app_role() = 'kepala_cashier');
DROP POLICY IF EXISTS profiles_admin_write ON public.profiles;
CREATE POLICY profiles_admin_write ON public.profiles FOR INSERT TO authenticated WITH CHECK (public.app_role() = 'kepala_cashier');
DROP POLICY IF EXISTS profiles_admin_update ON public.profiles;
CREATE POLICY profiles_admin_update ON public.profiles FOR UPDATE TO authenticated
  USING (public.app_role() = 'kepala_cashier') WITH CHECK (public.app_role() = 'kepala_cashier');

END
$migrasi$;
