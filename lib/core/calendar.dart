/// Pembantu kalender (murni). Minggu dimulai hari Senin; semua tanggal waktu lokal.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
int mondayIndex(DateTime d) => (d.weekday + 6) % 7; // Senin = 0 ... Minggu = 6

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Rentang setengah-terbuka [start, end).
class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

