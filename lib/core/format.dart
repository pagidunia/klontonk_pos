import 'package:intl/intl.dart';

final _angka = NumberFormat.decimalPattern('id_ID');

const bulanPendek = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const namaBulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
const namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const hariPendek = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Nama metode bayar untuk tampilan.
String methodLabel(String method) => switch (method) { 'tunai' => 'Tunai', 'utang' => 'Utang', _ => 'QRIS/Transfer' };

String formatQty(num qty) => _angka.format(qty);
String formatRupiah(num amount) => 'Rp ${_angka.format(amount)}';

String _dua(int n) => n.toString().padLeft(2, '0');

/// Waktu singkat untuk daftar: "22 Sep, 10.30".
String formatWhen(DateTime at) {
  final d = at.toLocal();
  return '${d.day} ${bulanPendek[d.month - 1]}, ${_dua(d.hour)}.${_dua(d.minute)}';
}

/// "12 Okt 2026, 16.15".
String formatDateTime(DateTime at) {
  final d = at.toLocal();
  return '${d.day} ${bulanPendek[d.month - 1]} ${d.year}, ${_dua(d.hour)}.${_dua(d.minute)}';
}

String formatTime(DateTime at) {
  final d = at.toLocal();
  return '${_dua(d.hour)}.${_dua(d.minute)}';
}

/// "7 Oktober 2026".
String formatDateLong(DateTime d) => '${d.day} ${namaBulan[d.month - 1]} ${d.year}';

/// "Senin, 7 Okt 2026".
String formatDateWithWeekday(DateTime d) => '${namaHari[(d.weekday + 6) % 7]}, ${d.day} ${bulanPendek[d.month - 1]} ${d.year}';

/// Postgres memberi waktu 6 digit pecahan detik; ringkas jadi milidetik agar DateTime.parse aman.
DateTime parseWaktu(String iso) => DateTime.parse(iso.replaceAllMapped(RegExp(r'(\.\d{3})\d+'), (m) => m[1]!));

String relativeTime(DateTime at, [DateTime? now]) {
  final menit = (now ?? DateTime.now()).difference(at).inMinutes;
  if (menit < 1) return 'Baru saja';
  if (menit < 60) return '$menit menit lalu';
  final jam = menit ~/ 60;
  if (jam < 24) return '$jam jam lalu';
  return '${at.toLocal().day} ${bulanPendek[at.toLocal().month - 1]}';
}

String sapaan([DateTime? now]) {
  final jam = (now ?? DateTime.now()).hour;
  if (jam < 11) return 'Selamat Pagi';
  if (jam < 15) return 'Selamat Siang';
  if (jam < 18) return 'Selamat Sore';
  return 'Selamat Malam';
}
