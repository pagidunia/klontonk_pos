import 'package:flutter/material.dart';

import '../theme.dart';

/// Dialog konfirmasi / pemberitahuan. Tanpa [cancelText] hanya ada satu tombol.
Future<bool> showConfirmDialog(BuildContext context, {required String title, required String message, required String confirmText, String? cancelText, bool danger = false}) async {
  final p = context.pal;
  final hasil = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(child: Text(message, style: TextStyle(color: p.textSecondary, height: 1.4))),
      actions: [
        if (cancelText != null) TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelText)),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: danger ? FilledButton.styleFrom(backgroundColor: p.danger) : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );
  // Menutup lewat latar/tombol kembali: pemberitahuan (tanpa tombol batal) dianggap "OK".
  return hasil ?? (cancelText == null);
}
