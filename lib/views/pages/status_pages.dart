import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/common.dart';

class ForbiddenPage extends StatelessWidget {
  const ForbiddenPage({super.key, this.subtitle = 'Halaman ini hanya dapat diakses oleh Admin.', this.title = 'Butuh Hak Akses Admin', this.hint = 'Jika Anda merasa ini keliru, hubungi admin pusat Anda.'});
  final String subtitle;
  final String title;
  final String hint;

  /// Untuk halaman input stok / harga: hanya akun tenant.
  const ForbiddenPage.tenantOnly({super.key})
      : subtitle = 'Stok tenant hanya bisa diinput oleh tenant itu sendiri.',
        title = 'Khusus Akun Tenant',
        hint = 'Akun admin hanya dapat melihat stok. Masuk dengan akun tenant untuk mengubahnya.';

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PageScroll(children: [
      PageHeader(greeting: 'Akses Ditolak', title: '403', subtitle: subtitle),
      SectionCard(
        child: Column(children: [
          const SizedBox(height: 12),
          CircleAvatar(radius: 32, backgroundColor: p.danger.withValues(alpha: 0.12), child: Icon(Icons.lock_outline, color: p.danger, size: 30)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(hint, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
          const SizedBox(height: 12),
        ]),
      ),
    ]);
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) => PageScroll(children: [
        const PageHeader(greeting: 'Tidak Ditemukan', title: '404', subtitle: 'Halaman yang Anda tuju tidak ditemukan.'),
        SectionCard(child: EmptyNote('Alamat halaman mungkin salah atau halaman sudah dipindahkan.', action: FilledButton(onPressed: () => context.go('/beranda'), child: const Text('Kembali ke Beranda')))),
      ]);
}
