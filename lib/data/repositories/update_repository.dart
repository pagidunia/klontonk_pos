import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';
import '../models/models.dart';

const _table = 'app_updates';
const _columns = 'id,kind,title,description,color,sort_order';

/// Info update (hanya baca).
class UpdateRepository {
  UpdateRepository(this._db);
  final SupabaseClient _db;

  Future<Result<List<AppUpdate>>> list() => guard(() async {
        // id berupa kode teks (U001, ...): jangan jadi pengurut utama ('U1000' < 'U999' secara alfabet).
        final rows = await _db.from(_table).select(_columns).order('sort_order').order('created_at').order('id');
        return rows.map(AppUpdate.fromRow).toList();
      });
}
