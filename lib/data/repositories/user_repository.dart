import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';
import '../models/models.dart';
import 'auth_repository.dart';

/// Manajemen akun (khusus admin; dijaga RLS).
class UserRepository {
  UserRepository(this._db);
  final SupabaseClient _db;

  Future<Result<List<AppUser>>> list() => guard(() async {
        final rows = await _db.from('profiles').select(profileColumns).order('created_at').order('username');
        return rows.map(AppUser.fromJson).toList();
      });

  Future<Result<bool>> usernameTaken(String username) => guard(() async {
        final rows = await _db.from('profiles').select('id').eq('username', username);
        return rows.isNotEmpty;
      });

  Future<Result<void>> insertProfile({required String id, required String username, required String name, required String role, required String avatar, required String tenantId}) => guard(() async {
        await _db.from('profiles').insert({'id': id, 'username': username, 'name': name, 'role': role, 'avatar': avatar, 'tenant_id': tenantId});
      });

  /// Database menolak hapus diri sendiri / admin terakhir.
  Future<Result<void>> delete(String username) => guard(() async {
        await _db.rpc('delete_app_user', params: {'p_username': username});
      });
}
