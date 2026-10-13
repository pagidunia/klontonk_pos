import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/result.dart';

const pageSize = 1000; // batas baris per permintaan di Supabase

/// Ambil semua baris (Supabase membatasi 1000 per permintaan): halaman demi halaman sampai habis.
/// [makeQuery] dipanggil ulang per halaman karena builder hanya sekali pakai.
Future<Result<List<Map<String, dynamic>>>> fetchAllRows(PostgrestTransformBuilder<List<Map<String, dynamic>>> Function() makeQuery) => guard(() async {
      final rows = <Map<String, dynamic>>[];
      for (var from = 0;; from += pageSize) {
        final page = await makeQuery().range(from, from + pageSize - 1);
        rows.addAll(page);
        if (page.length < pageSize) return rows;
      }
    });
