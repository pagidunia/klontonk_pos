import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';
import '../models/models.dart';

const _table = 'app_updates';
const _columns = 'id,kind,title,description,color,sort_order';

class UpdateRepository {
  UpdateRepository(this._db);
  final SupabaseClient _db;

  Future<Result<List<AppUpdate>>> list() => guard(() async {
        // id berupa kode teks (U001, ...): jangan jadi pengurut utama ('U1000' < 'U999' secara alfabet).
        final rows = await _db.from(_table).select(_columns).order('sort_order').order('created_at').order('id');
        return rows.map(AppUpdate.fromRow).toList();
      });

  Future<Result<void>> add({required String kind, required String title, required String? description, required String color, required int sortOrder}) => guard(() async {
        await _db.from(_table).insert({'kind': kind, 'title': title, 'description': description, 'color': color, 'sort_order': sortOrder});
      });

  Future<Result<void>> update(String id, {required String kind, required String title, required String? description, required String color}) => guard(() async {
        await _db.from(_table).update({'kind': kind, 'title': title, 'description': description, 'color': color}).eq('id', id);
      });

  Future<Result<void>> remove(String id) => guard(() async {
        await _db.from(_table).delete().eq('id', id);
      });
}
