import 'package:flutter_test/flutter_test.dart';
import 'package:klontonk_pos/domain/permissions.dart';

// Jatah dari Supabase (tabel role_menus), sama dengan isi awal db/role-menus.sql.
const _kepalaDb = {
  '/stok/awal', '/stok/keluar-laku', '/stok/retur', '/stok/total', '/kasir', '/kasir/utang',
  '/laporan/stok-awal', '/laporan/stok-keluar', '/laporan/stok-retur', '/laporan/stok-total', '/laporan/keuangan',
  '/harga', '/catatan', '/info-update',
  '/beranda/aksi/transaksi', '/beranda/aksi/cek-stok', '/beranda/aksi/update-harga', '/beranda/aksi/laporan-kasir', '/beranda/aksi/retur',
};
const _kasirDb = {
  '/stok/keluar-laku', '/stok/total', '/kasir', '/kasir/utang', '/laporan/stok-keluar', '/laporan/stok-total', '/catatan', '/info-update',
  '/beranda/aksi/transaksi', '/beranda/aksi/cek-stok', '/beranda/aksi/laporan-kasir',
};

void main() {
  const kepala = roleKepalaCashier;
  const kasir = roleCashier;

  test('kepala_cashier: 11 menu jatahnya terbuka', () {
    const jatah = ['/stok/awal', '/stok/keluar-laku', '/stok/retur', '/stok/total', '/kasir', '/laporan/stok-awal', '/laporan/stok-keluar', '/laporan/stok-retur', '/laporan/stok-total', '/laporan/keuangan', '/harga'];
    for (final p in jatah) {
      expect(canOpen(kepala, p, menuDb: _kepalaDb), isTrue, reason: p);
    }
  });

  test('cashier: hanya 5 menu jatahnya yang terbuka', () {
    for (final p in ['/stok/keluar-laku', '/stok/total', '/kasir', '/laporan/stok-keluar', '/laporan/stok-total']) {
      expect(canOpen(kasir, p, menuDb: _kasirDb), isTrue, reason: p);
    }
  });

  test('cashier ditolak di menu terkelola lain', () {
    for (final p in ['/stok/awal', '/stok/retur', '/laporan/stok-awal', '/laporan/stok-retur', '/laporan/keuangan', '/harga']) {
      expect(canOpen(kasir, p, menuDb: _kasirDb), isFalse, reason: p);
    }
  });

  test('Aksi Cepat Beranda: cashier Transaksi, Cek Stok, Laporan Kasir', () {
    String k(String x) => '$awalanAksiCepat$x';
    for (final x in ['transaksi', 'cek-stok', 'laporan-kasir']) {
      expect(canOpen(kasir, k(x), menuDb: _kasirDb), isTrue, reason: x);
    }
    for (final x in ['update-harga', 'retur']) {
      expect(canOpen(kasir, k(x), menuDb: _kasirDb), isFalse, reason: x);
    }
    for (final x in ['transaksi', 'cek-stok', 'update-harga', 'laporan-kasir', 'retur']) {
      expect(canOpen(kepala, k(x), menuDb: _kepalaDb), isTrue, reason: x);
    }
  });

  test('jatah mengikuti tabel: mengubah baris mengubah akses', () {
    expect(canOpen(kasir, '/laporan/keuangan', menuDb: {..._kasirDb, '/laporan/keuangan'}), isTrue);
    expect(canOpen(kepala, '/harga', menuDb: {..._kepalaDb}..remove('/harga')), isFalse);
  });

  test('metode Utang ikut tabel: tersembunyi bila barisnya tidak ada', () {
    expect(canOpen(kasir, '/kasir/utang', menuDb: _kasirDb), isTrue);
    expect(canOpen(kasir, '/kasir/utang', menuDb: {..._kasirDb}..remove('/kasir/utang')), isFalse);
  });

  test('Tambah User tersembunyi sampai barisnya ada di tabel', () {
    expect(canOpen(kepala, '/users', menuDb: _kepalaDb), isFalse);
    expect(canOpen(kepala, '/users', menuDb: {..._kepalaDb, '/users'}), isTrue);
  });

  test('tidak ada jatah bawaan di kode: jatah belum termuat -> menu terkelola tersembunyi', () {
    for (final p in menuTerkelola) {
      expect(canOpen(kepala, p), isFalse, reason: p);
      expect(canOpen(kasir, p), isFalse, reason: p);
    }
  });

  test('Catatan dan Info Update ikut tabel: tersembunyi bila barisnya tidak ada', () {
    expect(canOpen(kasir, '/catatan', menuDb: _kasirDb), isTrue);
    expect(canOpen(kasir, '/info-update', menuDb: {..._kasirDb}..remove('/info-update')), isFalse);
    expect(canOpen(kepala, '/catatan', menuDb: {..._kepalaDb}..remove('/catatan')), isFalse);
  });

  test('halaman sistem (Beranda, Akun, Pengaturan) terbuka untuk semua role login, walau jatah kosong', () {
    for (final p in ['/beranda', '/akun', '/pengaturan']) {
      expect(canOpen(kasir, p, menuDb: const {}), isTrue, reason: p);
      expect(canOpen(kepala, p), isTrue, reason: p);
    }
  });

  test('belum login: semua ditolak', () {
    expect(canOpen(null, '/kasir', menuDb: _kasirDb), isFalse);
    expect(canOpen(null, '/beranda'), isFalse);
  });
}
