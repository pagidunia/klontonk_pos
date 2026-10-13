import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';
import '../models/models.dart';
import 'supabase_helpers.dart';

const _select = 'tenant_id,no,at,cashier,kind,item_id,name,unit,qty,amount,reason,note';

class ReturnRepository {
  ReturnRepository(this._db);
  final SupabaseClient _db;

  Future<Result<Map<String, List<StockReturn>>>> fetchAll() async {
    final result = await fetchAllRows(() => _db.from('stock_returns').select(_select).order('at').order('no'));
    switch (result) {
      case Err(:final error):
        return Err(error);
      case Ok(:final data):
        final grouped = <String, List<StockReturn>>{};
        for (final row in data) {
          (grouped[row['tenant_id'] as String] ??= []).add(StockReturn.fromRow(row));
        }
        return Ok(grouped);
    }
  }

  /// Retur dicatat HANYA lewat fungsi database process_return() (atomik: kunci stok, periksa, ubah stok, catat).
  Future<Result<StockReturn>> process({required String tenant, required String kind, required String itemId, required int qty, required String reason, String? note}) => guard(() async {
        final data = await _db.rpc('process_return', params: {
          'p_tenant': tenant,
          'p_kind': kind,
          'p_item_id': itemId,
          'p_qty': qty,
          'p_reason': reason,
          'p_note': (note ?? '').isEmpty ? null : note,
        });
        return StockReturn.fromRow(Map<String, dynamic>.from(data as Map));
      });
}
