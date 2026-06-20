import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import 'auth_message_listener.dart';
import 'auth_providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isInvited = await ref.read(authControllerProvider.notifier).register(
          email: _emailController.text.trim(),
          nama: _namaController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    final error = ref.read(authControllerProvider).errorMessage;
    if (error != null) return; // error sudah dihandle listenAuthMessages

    if (isInvited) {
      // User diundang → langsung ke dashboard
      context.go(AppRoutes.dashboard);
    } else {
      // Owner baru → perlu buat koperasi
      context.go(AppRoutes.createKoperasi);
    }
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
          // Background decorations
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ).animate().scale(duration: 1200.ms, curve: Curves.easeOutBack),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.06),
              ),
            ),
          ).animate().scale(delay: 200.ms, duration: 1200.ms),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Back Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => context.go(AppRoutes.login),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: 24),

                      // Header
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ).animate().fadeIn(delay: 100.ms).scale(duration: 600.ms),
                      const SizedBox(height: 20),

                      Text(
                        'Buat Akun',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: const Color(0xFF1E293B),
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 6),
                      Text(
                        'Daftarkan akun koperasi Anda',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 36),

                      // Form Fields
                      _buildLabel('Nama Lengkap'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _namaController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan nama lengkap Anda',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                        validator: (value) {
                          final nama = value?.trim() ?? '';
                          if (nama.isEmpty) return 'Nama lengkap wajib diisi.';
                          if (nama.length < 3) {
                            return 'Nama minimal 3 karakter.';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.05),
                      const SizedBox(height: 16),

                      _buildLabel('Alamat Email'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'email@koperasi.id',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Email wajib diisi.';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                            return 'Format email tidak valid.';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05),
                      const SizedBox(height: 16),

                      _buildLabel('Kata Sandi'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'Minimal 8 karakter',
                          prefixIcon: const Icon(Icons.lock_person_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty) return 'Password wajib diisi.';
                          if (password.length < 8) {
                            return 'Password minimal 8 karakter.';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 450.ms).slideX(begin: -0.05),
                      const SizedBox(height: 16),

                      _buildLabel('Konfirmasi Kata Sandi'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Ulangi kata sandi',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Konfirmasi password tidak cocok.';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.05),
                      const SizedBox(height: 36),

                      // Submit Button
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
                                  'Daftar Sekarang',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ).animate().fadeIn(delay: 600.ms).scale(
                            begin: const Offset(0.95, 0.95),
                          ),
                      const SizedBox(height: 20),

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sudah punya akun? ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          TextButton(
                            onPressed: authState.isLoading
                                ? null
                                : () => context.go(AppRoutes.login),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Masuk',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 700.ms),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF374151),
        letterSpacing: 0.2,
      ),
    );
  }
}
