import '../core/result.dart';
import '../data/local/local_stores.dart';
import '../data/models/models.dart';

/// Kode PostgREST: fungsi RPC dengan parameter itu tidak ada di database (skema belum diperbarui).
const schemaMissing = 'PGRST202';

typedef SendEntry = Future<Result<Sale>> Function(OutboxEntry entry);

class FlushSummary {
  FlushSummary({this.stopped});
  final synced = <({OutboxEntry entry, Sale sale})>[];
  final failed = <({OutboxEntry entry, String error})>[];
  int remaining = 0;

  /// 'offline' | 'expired' | 'network' | 'schema' | 'no-session' | null
  String? stopped;
}

/// Mengirim antrean penjualan offline ke database.
///   - Urut dari yang terlama; hanya entri milik user yang sedang login.
///   - Jaringan putus / sesi berakhir -> berhenti, entri tetap 'pending'.
///   - Ditolak server (mis. harga belum diisi) -> ditandai 'failed', lanjut ke entri lain.
Future<FlushSummary> flushOutbox({required OutboxStore outbox, required SendEntry send, required String userId, bool Function()? isOnline}) async {
  final summary = FlushSummary();
  final queue = outbox.list().where((e) => e.isPending && e.userId == userId).toList();

  for (final entry in queue) {
    if (isOnline != null && !isOnline()) {
      summary.stopped = 'offline';
      break;
    }

    Result<Sale> result;
    try {
      result = await send(entry);
    } catch (error) {
      result = Err(AppError.from(error));
    }

    switch (result) {
      case Ok(:final data):
        await outbox.remove(entry.clientId);
        summary.synced.add((entry: entry, sale: data));
        continue;
      case Err(:final error):
        if (error.expired) {
          summary.stopped = 'expired';
        } else if (error.isNetwork || error.code == schemaMissing) {
          await outbox.update(entry.clientId, (e) => e.copyWith(attempts: e.attempts + 1));
          summary.stopped = error.isNetwork ? 'network' : 'schema';
        } else {
          await outbox.update(entry.clientId, (e) => e.copyWith(status: 'failed', error: error.message, attempts: e.attempts + 1));
          summary.failed.add((entry: entry, error: error.message));
          continue;
        }
    }
    break;
  }

  summary.remaining = outbox.list().where((e) => e.isPending && e.userId == userId).length;
  return summary;
}
