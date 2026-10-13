import 'package:flutter_test/flutter_test.dart';
import 'package:klontonk_pos/core/format.dart';

void main() {
  test('formatRupiah dan formatQty memakai pemisah ribuan Indonesia', () {
    expect(formatRupiah(1250000), 'Rp 1.250.000');
    expect(formatQty(1000), '1.000');
  });

  test('parseWaktu meringkas pecahan detik 6 digit', () {
    final d = parseWaktu('2026-10-12T09:15:30.123456+00:00');
    expect(d.toUtc().millisecond, 123);
  });

  test('relativeTime', () {
    final now = DateTime(2026, 10, 12, 12);
    expect(relativeTime(DateTime(2026, 10, 12, 11, 59, 30), now), 'Baru saja');
    expect(relativeTime(DateTime(2026, 10, 12, 11, 30), now), '30 menit lalu');
    expect(relativeTime(DateTime(2026, 10, 12, 6), now), '6 jam lalu');
    expect(relativeTime(DateTime(2026, 10, 9, 12), now), '9 Okt');
  });

  test('sapaan menurut jam', () {
    expect(sapaan(DateTime(2026, 1, 1, 8)), 'Selamat Pagi');
    expect(sapaan(DateTime(2026, 1, 1, 13)), 'Selamat Siang');
    expect(sapaan(DateTime(2026, 1, 1, 16)), 'Selamat Sore');
    expect(sapaan(DateTime(2026, 1, 1, 20)), 'Selamat Malam');
  });

  test('formatDateWithWeekday', () {
    expect(formatDateWithWeekday(DateTime(2026, 10, 7)), 'Rabu, 7 Okt 2026');
  });
}
