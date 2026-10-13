import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/result.dart';
import '../models/models.dart';
import 'supabase_helpers.dart';

const _select = 'tenant_id,no,at,cashier,method,total,paid,client_id,offline,review_note,lines:sale_lines(item_id,name,unit,qty,price)';
// Cadangan bila database belum diperbarui (kolom baru belum ada): tanpa penanda offline.
const _selectLegacy = 'tenant_id,no,at,cashier,method,total,paid,lines:sale_lines(item_id,name,unit,qty,price)';
const columnMissing = '42703'; // undefined_column

class SalesRepository {
  SalesRepository(this._db);
  final SupabaseClient _db;

  /// Riwayat penjualan per tenant + himpunan client_id yang sudah ada di database.
  Future<Result<({Map<String, List<Sale>> byTenant, Set<String> clientIds})>> fetchAll() async {
    var result = await fetchAllRows(() => _db.from('sales').select(_select).order('at').order('no'));
    if (result case Err(:final error) when error.code == columnMissing) {
      result = await fetchAllRows(() => _db.from('sales').select(_selectLegacy).order('at').order('no'));
    }
    switch (result) {
      case Err(:final error):
        return Err(error);
      case Ok(:final data):
        final grouped = <String, List<Sale>>{};
        final ids = <String>{};
        for (final row in data) {
          (grouped[row['tenant_id'] as String] ??= []).add(Sale.fromServer(row, lineFromRow: true));
          final id = row['client_id'];
          if (id is String) ids.add(id);
        }
        return Ok((byTenant: grouped, clientIds: ids));
    }
  }

  /// Panggil fungsi database checkout(): satu transaksi yang mengunci stok, memeriksa cukup,
  /// mengurangi stok, menghitung total dari harga di database, dan membuat nomor transaksi.
  /// [extra] berisi p_client_id (anti-ganda) dan, untuk pengiriman antrean offline, p_offline/p_at/p_expected_total.
  Future<Result<Sale>> checkout({
    required String tenant,
    required String method,
    required int paid,
    required List<({String id, int qty})> lines,
    Map<String, Object?> extra = const {},
    Duration? timeout,
  }) =>
      guard(() async {
        final call = _db.rpc('checkout', params: {
          'p_tenant': tenant,
          'p_method': method,
          'p_paid': paid,
          'p_lines': [for (final l in lines) {'id': l.id, 'qty': l.qty}],
          ...extra,
        });
        final data = await call.timeout(timeout ?? AppConfig.checkoutTimeout);
        return Sale.fromServer(Map<String, dynamic>.from(data as Map), lineFromRow: false);
      });
}
