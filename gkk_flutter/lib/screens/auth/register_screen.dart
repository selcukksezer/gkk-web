import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _submitRegister() async {
    await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          deviceId: 'flutter-mobile',
          referralCode: _referralController.text.trim().isEmpty
              ? null
              : _referralController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authProvider);
    final bool isLoading = authState.status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (AuthState? previous, AuthState next) {
      if (!mounted) return;

      if (next.status == AuthStatus.authenticated) {
        context.go(AppRoutes.home);
        return;
      }

      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Kayit')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Kullanici Adi'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Sifre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _referralController,
                decoration: const InputDecoration(labelText: 'Referans Kodu (opsiyonel)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: isLoading ? null : _submitRegister,
                child: Text(isLoading ? 'Kayit yapiliyor...' : 'Kayit Ol'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isLoading ? null : () => context.go(AppRoutes.login),
                child: const Text('Giris Ekranina Don'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
