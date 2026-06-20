import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import 'auth_providers.dart';

class CreateKoperasiPage extends ConsumerStatefulWidget {
  const CreateKoperasiPage({super.key});

  @override
  ConsumerState<CreateKoperasiPage> createState() => _CreateKoperasiPageState();
}

class _CreateKoperasiPageState extends ConsumerState<CreateKoperasiPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaKoperasiController = TextEditingController();
  final _alamatController = TextEditingController();
  final _teleponController = TextEditingController();

  @override
  void dispose() {
    _namaKoperasiController.dispose();
    _alamatController.dispose();
    _teleponController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final session = ref.read(authSessionProvider).valueOrNull;
    if (session == null) {
      if (mounted) context.go(AppRoutes.login);
      return;
    }

    final success = await ref
        .read(koperasiFormControllerProvider.notifier)
        .createKoperasi(
          userId: session.user.id,
          namaKoperasi: _namaKoperasiController.text,
          alamat: _alamatController.text.isEmpty
              ? null
              : _alamatController.text,
          telepon: _teleponController.text.isEmpty
              ? null
              : _teleponController.text,
        );

    if (!mounted) return;

    if (success) {
      // Invalidate profile provider agar refresh dengan koperasi_id baru
      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentKoperasiProvider);
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(koperasiFormControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative background
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.06),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step indicator
                    _buildStepIndicator(theme),
                    const SizedBox(height: 32),

                    // Header Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.store_mall_directory_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                    ).animate().fadeIn(delay: 100.ms).scale(duration: 600.ms),
                    const SizedBox(height: 20),

                    Text(
                      'Buat Koperasi',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: const Color(0xFF1E293B),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 8),
                    Text(
                      'Isi informasi koperasi Anda untuk mulai menggunakan sistem POS',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 36),

                    // Info Card
                    _buildInfoCard(theme),
                    const SizedBox(height: 28),

                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLabel('Nama Koperasi *'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _namaKoperasiController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'contoh: Koperasi Maju Bersama',
                              prefixIcon:
                                  Icon(Icons.store_mall_directory_rounded),
                            ),
                            validator: (value) {
                              final nama = value?.trim() ?? '';
                              if (nama.isEmpty) {
                                return 'Nama koperasi wajib diisi.';
                              }
                              if (nama.length < 3) {
                                return 'Nama minimal 3 karakter.';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.05),
                          const SizedBox(height: 16),

                          _buildLabel('Alamat'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _alamatController,
                            textInputAction: TextInputAction.next,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'Jl. Contoh No. 1, Desa Makmur',
                              prefixIcon:
                                  Icon(Icons.location_on_rounded),
                            ),
                          ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05),
                          const SizedBox(height: 16),

                          _buildLabel('Nomor Telepon'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _teleponController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              hintText: '0812-xxxx-xxxx',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return null;
                              if (value.length < 8) {
                                return 'Nomor telepon tidak valid.';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 450.ms).slideX(begin: -0.05),
                          const SizedBox(height: 36),

                          // Error message
                          if (formState.errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.error
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 18,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      formState.errorMessage!,
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn().slideY(begin: 0.2, end: 0),

                          // Submit button
                          SizedBox(
                            height: 60,
                            child: FilledButton.icon(
                              onPressed: formState.isLoading ? null : _submit,
                              icon: formState.isLoading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_rounded),
                              label: Text(
                                formState.isLoading
                                    ? 'Membuat Koperasi...'
                                    : 'Buat & Mulai Gunakan',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 500.ms).scale(
                                begin: const Offset(0.95, 0.95),
                              ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    return Row(
      children: [
        _stepDot(theme, true, '1', 'Akun'),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ),
        _stepDot(theme, true, '2', 'Koperasi'),
        Expanded(
          child: Container(
            height: 2,
            color: const Color(0xFFE2E8F0),
          ),
        ),
        _stepDot(theme, false, '3', 'Dashboard'),
      ],
    );
  }

  Widget _stepDot(ThemeData theme, bool isActive, String number, String label) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? theme.colorScheme.primary
                : const Color(0xFFE2E8F0),
          ),
          child: Center(
            child: isActive && number != '2'
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    number,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive
                ? theme.colorScheme.primary
                : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Anda akan menjadi Owner dari koperasi ini dan memiliki akses penuh ke seluruh fitur sistem.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
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
