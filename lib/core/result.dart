import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Semua akses data mengembalikan [Result] dan TIDAK PERNAH melempar error. status 0 = tidak ada
/// jaringan / server tidak menjawab.
class AppError {
  const AppError({required this.status, this.code = '', required this.message, this.expired = false});

  final int status;
  final String code;
  final String message;

  /// true bila sesi login sudah tidak berlaku (HTTP 401).
  final bool expired;

  static const networkMessage = 'Server tidak terjangkau. Periksa koneksi lalu coba lagi.';

  bool get isNetwork => status == 0 && code == 'network';

  factory AppError.network() => const AppError(status: 0, code: 'network', message: networkMessage);

  factory AppError.from(Object error) {
    if (error is PostgrestException) {
      final status = int.tryParse(error.code ?? '') ?? 0;
      final expired = error.code == 'PGRST301' || error.message.toLowerCase().contains('jwt expired');
      return AppError(
        status: expired ? 401 : (status >= 100 && status < 600 ? status : 400),
        code: error.code ?? '',
        message: error.message,
        expired: expired,
      );
    }
    if (error is AuthException) {
      if (error is AuthRetryableFetchException) return AppError.network();
      final status = int.tryParse(error.statusCode ?? '') ?? 400;
      return AppError(status: status, code: error.code ?? '', message: error.message, expired: status == 401);
    }
    if (error is SocketException || error is TimeoutException || error is http.ClientException) return AppError.network();
    return AppError(status: 0, message: error.toString());
  }
}

sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.data);
  final T data;
}

final class Err<T> extends Result<T> {
  const Err(this.error);
  final AppError error;
}

Future<Result<T>> guard<T>(Future<T> Function() operation) async {
  try {
    return Ok(await operation());
  } catch (error) {
    return Err(AppError.from(error));
  }
}

/// Pesan siap tampil. [byCode] = pesan khusus per kode galat Postgres.
String describeError(AppError error, {Map<String, String> byCode = const {}, String forbidden = 'Tidak punya akses untuk tindakan ini.'}) {
  if (error.expired) return 'Sesi berakhir. Silakan login ulang.';
  final khusus = byCode[error.code];
  if (khusus != null) return khusus;
  if (error.status == 403 || error.code == '42501') return forbidden;
  return error.message;
}
