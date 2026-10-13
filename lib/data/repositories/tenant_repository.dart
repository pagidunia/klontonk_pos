import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';
import '../models/models.dart';

class TenantRepository {
  TenantRepository(this._db);
  final SupabaseClient _db;

  Future<Result<List<Tenant>>> list() => guard(() async {
        final rows = await _db.from('tenants').select('id,name').order('id');
        return rows.map(Tenant.fromJson).toList();
      });
}
