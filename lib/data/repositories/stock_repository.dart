import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';
import '../models/models.dart';
import 'supabase_helpers.dart';

const _table = 'stock_items';
const _columns = 'tenant_id,id,name,qty,unit,barcode,price';

class StockRepository {
  StockRepository(this._db);
  final SupabaseClient _db;

  /// Seluruh stok (RLS: admin semua tenant, kasir hanya tenant sendiri), dikelompokkan per tenant.
  Future<Result<Map<String, List<StockItem>>>> fetchAll() async {
    final result = await fetchAllRows(() => _db.from(_table).select(_columns).order('created_at').order('name'));
    switch (result) {
      case Err(:final error):
        return Err(error);
      case Ok(:final data):
        final grouped = <String, List<StockItem>>{};
        for (final row in data) {
          (grouped[row['tenant_id'] as String] ??= []).add(StockItem.fromRow(row));
        }
        return Ok(grouped);
    }
  }

  /// Tambah atau ganti satu barang (upsert menurut kunci tenant_id + id).
  Future<Result<void>> upsert(String tenant, StockItem item) => guard(() async {
        await _db.from(_table).upsert({
          'tenant_id': tenant,
          'id': item.id,
          'name': item.name,
          'qty': item.qty,
          'unit': item.unit,
          'barcode': (item.barcode ?? '').isEmpty ? null : item.barcode,
          'price': item.price,
        }, onConflict: 'tenant_id,id');
      });

  Future<Result<void>> delete(String tenant, String id) => guard(() async {
        await _db.from(_table).delete().eq('tenant_id', tenant).eq('id', id);
      });

  Future<Result<void>> setPrice(String tenant, String id, int price) => guard(() async {
        await _db.from(_table).update({'price': price}).eq('tenant_id', tenant).eq('id', id);
      });
}
