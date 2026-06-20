import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import 'auth_message_listener.dart';
import 'auth_providers.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authControllerProvider.notifier)
        .changePassword(_passwordController.text);

    if (mounted && ref.read(authControllerProvider).errorMessage == null) {
      _passwordController.clear();
      _confirmPasswordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    listenAuthMessages(ref, context);
    final authState = ref.watch(authControllerProvider);

    return AppScaffold(
      title: 'Ubah Password',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Dashboard',
          onPressed: () => context.go(AppRoutes.dashboard),
          icon: const Icon(Icons.dashboard_outlined),
        ),
      ],
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Tampilkan password'
                            : 'Sembunyikan password',
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (password.isEmpty) return 'Password baru wajib diisi.';
                      if (password.length < 8) {
                        return 'Password minimal 8 karakter.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmation,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmation
                            ? 'Tampilkan password'
                            : 'Sembunyikan password',
                        onPressed: () {
                          setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          );
                        },
                        icon: Icon(
                          _obscureConfirmation
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Konfirmasi password tidak sama.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: authState.isLoading ? null : _submit,
                    icon: authState.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.password_outlined),
                    label: const Text('Simpan Password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
