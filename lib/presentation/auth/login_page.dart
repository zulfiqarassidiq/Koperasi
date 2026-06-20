import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import 'auth_message_listener.dart';
import 'auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    listenAuthMessages(ref, context);
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
              ),
            ),
          ).animate().scale(duration: 1200.ms, curve: Curves.easeOutBack),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.05),
              ),
            ),
          ).animate().scale(delay: 200.ms, duration: 1200.ms),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo Section
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              Icons.point_of_sale_rounded,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ).animate().fadeIn().scale(duration: 600.ms),
                        const SizedBox(height: 24),
                        Text(
                          'Kasir POS Koperasi',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: const Color(0xFF1E293B),
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                        Text(
                          'Sistem Kasir Desa Terpadu',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                        const SizedBox(height: 48),

                        // Form Section
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Alamat Email',
                            hintText: 'admin@koperasi.id',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Email wajib diisi.';
                            if (!email.contains('@')) return 'Email tidak valid.';
                            return null;
                          },
                        ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Kata Sandi',
                            prefixIcon:
                                const Icon(Icons.lock_person_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Password wajib diisi.';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: authState.isLoading
                                ? null
                                : () => context.push(AppRoutes.forgotPassword),
                            child: const Text('Lupa sandi?'),
                          ),
                        ).animate().fadeIn(delay: 600.ms),
                        const SizedBox(height: 24),

                        // Login Button
                        SizedBox(
                          height: 60,
                          child: FilledButton(
                            onPressed: authState.isLoading ? null : _submit,
                            child: authState.isLoading
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Masuk ke Sistem',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ).animate().fadeIn(delay: 700.ms).scale(
                              begin: const Offset(0.9, 0.9),
                            ),
                        const SizedBox(height: 16),

                        // Register Button
                        SizedBox(
                          height: 60,
                          child: OutlinedButton.icon(
                            onPressed: authState.isLoading
                                ? null
                                : () => context.push(AppRoutes.register),
                            icon: const Icon(Icons.person_add_rounded),
                            label: const Text(
                              'Daftar Akun',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 800.ms).scale(
                              begin: const Offset(0.9, 0.9),
                            ),
                        const SizedBox(height: 40),

                        Text(
                          '© 2026 Koperasi Desa Digital',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ).animate().fadeIn(delay: 1000.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
