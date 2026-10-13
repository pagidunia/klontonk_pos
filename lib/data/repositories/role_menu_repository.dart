import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';

/// Jatah menu per role dari tabel `role_menus` (kolom role, menu). RLS: semua user login boleh
/// membaca; hanya kepala_cashier yang boleh mengubah.
class RoleMenuRepository {
  RoleMenuRepository(this._db);
  final SupabaseClient _db;

  /// Himpunan menu (alamat rute) yang boleh dibuka [role].
  Future<Result<Set<String>>> menusFor(String role) => guard(() async {
        final rows = await _db.from('role_menus').select('menu').eq('role', role);
        return rows.map((r) => r['menu'] as String).toSet();
      });
}
