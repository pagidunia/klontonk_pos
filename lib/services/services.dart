import 'package:flutter/material.dart';

import '../views/widgets/dialogs.dart';

enum ToastType { info, success, warning, danger }

/// Notifikasi singkat (SnackBar). Tidak butuh BuildContext sehingga bisa dipakai ViewModel.
class ToastService {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  void show(String message, {ToastType type = ToastType.info, Duration duration = const Duration(milliseconds: 3500)}) {
    const warna = {
      ToastType.info: Color(0xFF1E293B),
      ToastType.success: Color(0xFF14532D),
      ToastType.warning: Color(0xFF78350F),
      ToastType.danger: Color(0xFF7F1D1D),
    };
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: warna[type], duration: duration, behavior: SnackBarBehavior.floating));
  }
}

/// Dialog konfirmasi. Tidak butuh BuildContext sehingga bisa dipakai ViewModel.
class DialogService {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<bool> confirm({required String title, required String message, String confirmText = 'OK', String? cancelText, bool danger = false}) async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    return showConfirmDialog(context, title: title, message: message, confirmText: confirmText, cancelText: cancelText, danger: danger);
  }

  Future<void> notify({required String title, required String message}) => confirm(title: title, message: message, confirmText: 'Tutup');
}
