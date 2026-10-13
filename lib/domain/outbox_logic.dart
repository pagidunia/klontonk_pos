import '../data/models/models.dart';

const _methods = ['tunai', 'nontunai'];

int linesTotal(List<SaleLine> lines) => lines.fold(0, (s, l) => s + l.qty * l.price);

/// Membangun satu entri antrean offline. Mengembalikan (entry, error): salah satunya null.
({OutboxEntry? entry, String? error}) buildEntry({
  required String clientId,
  required String tenant,
  required String userId,
  required String cashier,
  required String method,
  required int? paid,
  required List<SaleLine> lines,
  DateTime? now,
}) {
  if (!_methods.contains(method)) return (entry: null, error: 'Metode bayar tidak valid.');
  if (lines.isEmpty) return (entry: null, error: 'Keranjang kosong.');
  if (!lines.every((l) => l.qty > 0 && l.price > 0)) return (entry: null, error: 'Jumlah dan harga barang tidak valid.');

  final total = linesTotal(lines);
  if (method == 'tunai' && (paid == null || paid < total)) return (entry: null, error: 'Uang diterima kurang dari total.');

  return (
    entry: OutboxEntry(
      clientId: clientId,
      tenant: tenant,
      userId: userId,
      cashier: cashier,
      at: now ?? DateTime.now(),
      method: method,
      paid: method == 'tunai' ? paid! : total,
      expectedTotal: total,
      lines: lines,
    ),
    error: null,
  );
}
