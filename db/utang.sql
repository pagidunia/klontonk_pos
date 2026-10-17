-- Fitur UTANG di menu Transaksi: penjualan dengan metode 'utang' + nama pelanggan + foto KTP.
-- Jalankan seluruh isi berkas di Supabase SQL Editor. Seluruhnya satu pernyataan DO, jadi atomik
-- (semua berhasil atau semua batal). Aman dijalankan ulang.
--
-- Isi:
--   1) sales.method boleh 'utang'. (paid tetap = total: nilai tagihan; status lunas/belum ada di sale_debts.)
--   2) Bucket penyimpanan PRIVAT 'ktp' (foto KTP = data pribadi): hanya pengguna yang berhak atas tenant
--      itu yang bisa mengunggah/membaca; tidak ada ubah/hapus lewat aplikasi; bukan publik.
--   3) Tabel sale_debts: nama pelanggan + lokasi foto KTP per penjualan utang (RLS per tenant).
--   4) checkout() menerima p_debt_name & p_debt_ktp dan mencatat utang dalam transaksi yang sama.
--      Utang hanya boleh saat online (butuh unggah foto) dan wajib nama + foto.
--   5) Menu Utang ('/kasir/utang') ditambahkan ke tabel role_menus untuk kedua role.
DO $migrasi$
BEGIN
  -- 1) metode utang
  ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_method_check;
  ALTER TABLE public.sales ADD CONSTRAINT sales_method_check CHECK (method IN ('tunai', 'nontunai', 'utang'));

  -- 2) bucket privat untuk foto KTP (maks 5 MB, hanya gambar)
  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES ('ktp', 'ktp', false, 5242880, ARRAY['image/jpeg', 'image/png'])
  ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = 5242880, allowed_mime_types = ARRAY['image/jpeg', 'image/png'];

  DROP POLICY IF EXISTS ktp_read ON storage.objects;
  CREATE POLICY ktp_read ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'ktp' AND public.can_access_tenant((storage.foldername(name))[1]));
  DROP POLICY IF EXISTS ktp_insert ON storage.objects;
  CREATE POLICY ktp_insert ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'ktp' AND public.can_access_tenant((storage.foldername(name))[1]));
  -- Penghapusan hanya untuk berkas yang diunggah user itu sendiri (pembersihan saat checkout gagal).
  DROP POLICY IF EXISTS ktp_delete_own ON storage.objects;
  CREATE POLICY ktp_delete_own ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'ktp' AND owner = auth.uid() AND public.can_access_tenant((storage.foldername(name))[1]));

  -- 3) data utang per penjualan
  CREATE TABLE IF NOT EXISTS public.sale_debts (
    tenant_id     text NOT NULL,
    sale_no       text NOT NULL,
    customer_name text NOT NULL CHECK (char_length(btrim(customer_name)) BETWEEN 2 AND 80),
    ktp_path      text NOT NULL CHECK (ktp_path ~ '^T[0-9]{3}/[0-9a-f-]{36}\.(jpg|png)$'),
    created_by    uuid NOT NULL DEFAULT auth.uid(),
    created_at    timestamptz NOT NULL DEFAULT now(),
    settled_at    timestamptz,
    PRIMARY KEY (tenant_id, sale_no),
    FOREIGN KEY (tenant_id, sale_no) REFERENCES public.sales (tenant_id, no) ON DELETE CASCADE
  );
  ALTER TABLE public.sale_debts ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS sale_debts_read ON public.sale_debts;
  CREATE POLICY sale_debts_read ON public.sale_debts FOR SELECT TO authenticated USING (public.can_access_tenant(tenant_id));
  -- Tidak ada kebijakan INSERT/UPDATE/DELETE: baris dibuat HANYA oleh fungsi checkout() (SECURITY DEFINER).

  -- 4) checkout() baru (dua parameter tambahan, bernilai bawaan NULL sehingga pemanggil lama tetap jalan).
--    Fungsi lama dihapus dulu agar tidak ada dua versi yang membingungkan PostgREST.
DROP FUNCTION IF EXISTS public.checkout(text, text, integer, jsonb, uuid, boolean, timestamptz, integer);

CREATE OR REPLACE FUNCTION public.checkout(p_tenant text, p_method text, p_paid integer, p_lines jsonb,
    p_client_id uuid DEFAULT NULL, p_offline boolean DEFAULT false, p_at timestamptz DEFAULT NULL,
    p_expected_total integer DEFAULT NULL, p_debt_name text DEFAULT NULL, p_debt_ktp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid     uuid := auth.uid();
  v_now     timestamptz := now();
  v_at      timestamptz := now();
  v_cashier text;
  v_total   bigint := 0;
  v_count   integer;
  v_found   integer := 0;
  v_base    text;
  v_no      text;
  v_suffix  integer := 1;
  v_paid    integer;
  v_lines   jsonb := '[]'::jsonb;
  v_notes   text[] := ARRAY[]::text[];
  v_note    text;
  v_existing public.sales%ROWTYPE;
  r         record;
BEGIN
  IF v_uid IS NULL OR public.app_role() IS NULL THEN
    RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
  END IF;
  IF NOT public.can_access_tenant(p_tenant) THEN
    RAISE EXCEPTION 'Tidak punya akses ke tenant ini.' USING ERRCODE = '42501';
  END IF;
  IF p_method NOT IN ('tunai', 'nontunai', 'utang') THEN
    RAISE EXCEPTION 'Metode bayar tidak valid.' USING ERRCODE = '22023';
  END IF;
  IF p_method = 'utang' THEN
    IF p_offline THEN
      RAISE EXCEPTION 'Penjualan utang hanya bisa dicatat saat online.' USING ERRCODE = 'P0001';
    END IF;
    IF p_debt_name IS NULL OR char_length(btrim(p_debt_name)) NOT BETWEEN 2 AND 80 THEN
      RAISE EXCEPTION 'Nama pelanggan utang wajib diisi (2-80 karakter).' USING ERRCODE = 'P0001';
    END IF;
    IF p_debt_ktp IS NULL OR p_debt_ktp !~ '^T[0-9]{3}/[0-9a-f-]{36}\.(jpg|png)$' OR split_part(p_debt_ktp, '/', 1) <> p_tenant THEN
      RAISE EXCEPTION 'Foto KTP pelanggan utang wajib dilampirkan.' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  IF jsonb_typeof(p_lines) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Keranjang tidak valid.' USING ERRCODE = '22023';
  END IF;

  -- Idempotensi: panggilan kedua dengan client_id yang sama menunggu yang pertama, lalu mengembalikan hasilnya.
  IF p_client_id IS NOT NULL THEN
    PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant || ':' || p_client_id::text, 0));
    SELECT * INTO v_existing FROM public.sales WHERE tenant_id = p_tenant AND client_id = p_client_id;
    IF FOUND THEN
      RETURN jsonb_build_object(
        'no', v_existing.no, 'at', v_existing.at, 'cashier', v_existing.cashier, 'method', v_existing.method,
        'total', v_existing.total, 'paid', v_existing.paid,
        'offline', v_existing.offline, 'review_note', v_existing.review_note,
        'lines', (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', l.item_id, 'name', l.name, 'unit', l.unit,
                                                                'qty', l.qty, 'price', l.price) ORDER BY l.item_id), '[]'::jsonb)
                    FROM public.sale_lines l WHERE l.tenant_id = p_tenant AND l.sale_no = v_existing.no));
    END IF;
  END IF;

  SELECT count(*) INTO v_count FROM jsonb_array_elements(p_lines);
  IF v_count < 1 OR v_count > 200
     OR v_count <> (SELECT count(DISTINCT e->>'id') FROM jsonb_array_elements(p_lines) e)
     OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_lines) e
                WHERE (e->>'id') IS NULL OR (e->>'qty') !~ '^[0-9]{1,7}$' OR (e->>'qty')::int < 1) THEN
    RAISE EXCEPTION 'Keranjang tidak valid.' USING ERRCODE = '22023';
  END IF;

  IF p_offline AND p_at IS NOT NULL THEN
    IF p_at <= v_now + interval '5 minutes' AND p_at >= v_now - interval '30 days' THEN
      v_at := LEAST(p_at, v_now);
    ELSE
      v_notes := array_append(v_notes, 'Waktu dari perangkat tidak wajar, memakai waktu sinkron.');
    END IF;
  END IF;

  FOR r IN
    SELECT s.id, s.name, s.unit, s.qty, s.price, q.want
    FROM public.stock_items s
    JOIN (SELECT e->>'id' AS id, (e->>'qty')::int AS want FROM jsonb_array_elements(p_lines) e) q ON q.id = s.id
    WHERE s.tenant_id = p_tenant
    ORDER BY s.id
    FOR UPDATE OF s
  LOOP
    v_found := v_found + 1;
    IF r.price IS NULL THEN
      RAISE EXCEPTION 'Harga "%" belum diisi.', r.name USING ERRCODE = 'P0001';
    END IF;
    IF r.qty < r.want THEN
      IF NOT p_offline THEN
        RAISE EXCEPTION 'Stok "%" tinggal % %.', r.name, r.qty, r.unit USING ERRCODE = 'P0001';
      END IF;
      v_notes := array_append(v_notes, format('Stok "%s" kurang: tersedia %s %s, terjual %s.', r.name, r.qty, r.unit, r.want));
    END IF;
    v_total := v_total + r.want::bigint * r.price;
    v_lines := v_lines || jsonb_build_object('id', r.id, 'name', r.name, 'unit', r.unit, 'qty', r.want, 'price', r.price);
  END LOOP;

  IF v_found <> v_count THEN
    RAISE EXCEPTION 'Ada barang yang sudah tidak ada di daftar stok.' USING ERRCODE = 'P0001';
  END IF;
  IF v_total < 1 OR v_total > 1000000000 THEN
    RAISE EXCEPTION 'Total belanja tidak valid.' USING ERRCODE = '22023';
  END IF;

  IF p_offline AND p_expected_total IS NOT NULL AND p_expected_total <> v_total THEN
    v_notes := array_append(v_notes, format('Total struk offline Rp %s berbeda dari total database Rp %s.', p_expected_total, v_total));
  END IF;

  -- Tunai: uang diterima; QRIS/transfer dan utang: sebesar total (utang = nilai tagihan).
  v_paid := CASE WHEN p_method = 'tunai' THEN p_paid ELSE v_total::int END;
  IF v_paid IS NULL OR v_paid < v_total THEN
    IF NOT p_offline OR v_paid IS NULL OR v_paid < 1 THEN
      RAISE EXCEPTION 'Uang diterima kurang dari total.' USING ERRCODE = 'P0001';
    END IF;
    v_notes := array_append(v_notes, format('Uang diterima Rp %s kurang dari total database Rp %s.', v_paid, v_total));
    v_paid := v_total::int;
  END IF;
  IF v_paid > 1000000000 THEN
    RAISE EXCEPTION 'Uang diterima terlalu besar.' USING ERRCODE = '22023';
  END IF;

  UPDATE public.stock_items s
     SET qty = GREATEST(s.qty - q.want, 0)
    FROM (SELECT e->>'id' AS id, (e->>'qty')::int AS want FROM jsonb_array_elements(p_lines) e) q
   WHERE s.tenant_id = p_tenant AND s.id = q.id;

  SELECT left(regexp_replace(name, '[^[:alnum:] .,''()&/+-]', '', 'g'), 60) INTO v_cashier
    FROM public.profiles WHERE id = v_uid;
  v_cashier := COALESCE(NULLIF(btrim(v_cashier), ''), 'Kasir');
  v_note := NULLIF(left(array_to_string(v_notes, ' '), 500), '');

  -- Nomor: TRX-YYYYMMDD-HHMMSS (waktu Jakarta); bila bentrok di detik yang sama, akhiran -2, -3, ...
  v_base := 'TRX-' || to_char(v_at AT TIME ZONE 'Asia/Jakarta', 'YYYYMMDD-HH24MISS');
  LOOP
    v_no := CASE WHEN v_suffix = 1 THEN v_base ELSE v_base || '-' || v_suffix END;
    BEGIN
      INSERT INTO public.sales (tenant_id, no, at, cashier, method, total, paid, client_id, offline, review_note)
      VALUES (p_tenant, v_no, v_at, v_cashier, p_method, v_total::int, v_paid, p_client_id, p_offline, v_note);
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_suffix := v_suffix + 1;
      IF v_suffix > 999 THEN RAISE EXCEPTION 'Gagal membuat nomor transaksi.' USING ERRCODE = 'P0001'; END IF;
    END;
  END LOOP;

  INSERT INTO public.sale_lines (tenant_id, sale_no, item_id, name, unit, qty, price)
  SELECT p_tenant, v_no, l->>'id', l->>'name', l->>'unit', (l->>'qty')::int, (l->>'price')::int
    FROM jsonb_array_elements(v_lines) l;

  IF p_method = 'utang' THEN
    INSERT INTO public.sale_debts (tenant_id, sale_no, customer_name, ktp_path, created_by)
    VALUES (p_tenant, v_no, btrim(p_debt_name), p_debt_ktp, v_uid);
  END IF;

  RETURN jsonb_build_object('no', v_no, 'at', v_at, 'cashier', v_cashier, 'method', p_method,
                            'total', v_total::int, 'paid', v_paid, 'offline', p_offline, 'review_note', v_note,
                            'lines', v_lines);
END;
$function$;

REVOKE ALL ON FUNCTION public.checkout(text, text, integer, jsonb, uuid, boolean, timestamptz, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.checkout(text, text, integer, jsonb, uuid, boolean, timestamptz, integer, text, text) TO authenticated;

-- 5) Menu Utang di tabel role_menus (kedua role; ubah barisnya untuk mengatur siapa yang boleh).
INSERT INTO public.role_menus (role, menu) VALUES
  ('kepala_cashier', '/kasir/utang'),
  ('cashier', '/kasir/utang')
ON CONFLICT DO NOTHING;
END
$migrasi$;
