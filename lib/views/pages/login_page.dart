import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../viewmodels/session_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _hide = true;
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final session = context.read<SessionViewModel>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final hasil = await session.login(_username.text, _password.text);
    if (!mounted) return;
    switch (hasil) {
      case LoginOk():
        break; // router mengarahkan ke beranda
      case LoginFail(:final error, :final locked):
        setState(() {
          _error = error;
          _busy = false;
        });
        if (locked) _startCountdown();
    }
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      final session = context.read<SessionViewModel>();
      if (!session.isLockedOut) {
        t.cancel();
        if (mounted) setState(() => _error = null);
      } else if (mounted) {
        setState(() => _error = 'Terlalu banyak percobaan. Coba lagi dalam ${session.lockoutSeconds} detik.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(child: Container(width: 72, height: 72, decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.point_of_sale, color: Colors.white, size: 38))),
                  const SizedBox(height: 18),
                  const Text('Klontonk POS', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Masuk untuk mulai berjualan', textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
                  const SizedBox(height: 28),
                  TextField(controller: _username, autofillHints: const [AutofillHints.username], autocorrect: false, enableSuggestions: false, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _hide,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide))),
                  ),
                  const SizedBox(height: 14),
                  FormError(_error),
                  const SizedBox(height: 6),
                  FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Memeriksa...' : 'Masuk')),
                  const SizedBox(height: 18),
                  Text(AppConfig.appVersion, textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
