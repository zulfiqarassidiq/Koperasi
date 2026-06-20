import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user_profile_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/role_badge.dart';
import '../../core/theme/theme_provider.dart';
import '../auth/auth_providers.dart';
import 'settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Memastikan error/success message dari controller tampil
    ref.listen<SettingsState>(settingsControllerProvider, (_, state) {
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
        ref.read(settingsControllerProvider.notifier).clearMessages();
      }
      if (state.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.successMessage!),
        ));
        ref.read(settingsControllerProvider.notifier).clearMessages();
      }
    });

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final koperasi = ref.watch(currentKoperasiProvider).valueOrNull;
    final session = ref.watch(authSessionProvider).valueOrNull;
    final email = session?.user.email ?? '-';

    if (profile == null) {
      return const AppScaffold(
        title: 'Settings',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isOwnerOrAdmin = profile.role == UserRole.owner || profile.role == UserRole.admin;

    return AppScaffold(
      title: 'Pengaturan',
      showBackButton: true,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // Section 1: Akun Saya
          _SectionTitle(title: 'Akun Saya'),
          _ProfileCard(
            profile: profile,
            email: email,
            koperasiName: koperasi?.namaKoperasi ?? '-',
          ),
          const SizedBox(height: 24),

          // Section 1.5: Tampilan (Theme)
          _SectionTitle(title: 'Tampilan'),
          const _ThemeCard(),
          const SizedBox(height: 24),

          // Section 2: Profil Koperasi (Owner/Admin)
          if (isOwnerOrAdmin) ...[
            _SectionTitle(title: 'Profil Koperasi'),
            _KoperasiCard(
              nama: koperasi?.namaKoperasi ?? '',
              alamat: koperasi?.alamat ?? '',
              telepon: koperasi?.telepon ?? '',
            ),
            const SizedBox(height: 24),
          ],

          // Section 3: Manajemen User (Owner/Admin)
          if (isOwnerOrAdmin) ...[
            _SectionTitle(title: 'Manajemen User'),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.people_alt_outlined),
                    title: const Text('Kelola Anggota & Undangan'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.userManagement),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Section 4: Informasi Aplikasi
          _SectionTitle(title: 'Informasi Aplikasi'),
          const Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('POS Koperasi'),
              subtitle: Text('Versi 1.0.0'),
            ),
          ),
          const SizedBox(height: 32),

          // Section 5: Logout
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              _showLogoutConfirm(context, ref);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Keluar dari Akun (Logout)'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authControllerProvider.notifier).logout();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profil Akun Widget
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({
    required this.profile,
    required this.email,
    required this.koperasiName,
  });

  final UserProfileModel profile;
  final String email;
  final String koperasiName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    profile.nama.isNotEmpty ? profile.nama[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nama,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          RoleBadge(role: profile.role),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Koperasi: $koperasiName', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showEditNameDialog(context, ref, profile.nama),
                    child: const Text('Ubah Nama'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(AppRoutes.changePassword),
                    child: const Text('Ganti Password'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Nama'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nama Lengkap'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(settingsControllerProvider.notifier).updateProfileName(controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Koperasi Profile Widget
// ─────────────────────────────────────────────────────────────────────────────
class _KoperasiCard extends ConsumerStatefulWidget {
  const _KoperasiCard({
    required this.nama,
    required this.alamat,
    required this.telepon,
  });

  final String nama;
  final String alamat;
  final String telepon;

  @override
  ConsumerState<_KoperasiCard> createState() => _KoperasiCardState();
}

class _KoperasiCardState extends ConsumerState<_KoperasiCard> {
  late TextEditingController _namaCtrl;
  late TextEditingController _alamatCtrl;
  late TextEditingController _teleponCtrl;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.nama);
    _alamatCtrl = TextEditingController(text: widget.alamat);
    _teleponCtrl = TextEditingController(text: widget.telepon);
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _alamatCtrl.dispose();
    _teleponCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(settingsControllerProvider).isLoading;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Informasi Koperasi', style: TextStyle(fontWeight: FontWeight.bold)),
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => setState(() => _isEditing = true),
                  )
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _namaCtrl,
              enabled: _isEditing,
              decoration: const InputDecoration(labelText: 'Nama Koperasi', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _alamatCtrl,
              enabled: _isEditing,
              decoration: const InputDecoration(labelText: 'Alamat', isDense: true),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teleponCtrl,
              enabled: _isEditing,
              decoration: const InputDecoration(labelText: 'Telepon', isDense: true),
              keyboardType: TextInputType.phone,
            ),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isLoading ? null : () {
                      setState(() {
                        _namaCtrl.text = widget.nama;
                        _alamatCtrl.text = widget.alamat;
                        _teleponCtrl.text = widget.telepon;
                        _isEditing = false;
                      });
                    },
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: isLoading ? null : () async {
                      if (_namaCtrl.text.trim().isEmpty) return;
                      final success = await ref.read(settingsControllerProvider.notifier).updateKoperasi(
                        namaKoperasi: _namaCtrl.text,
                        alamat: _alamatCtrl.text,
                        telepon: _teleponCtrl.text,
                      );
                      if (success && mounted) {
                        setState(() => _isEditing = false);
                      }
                    },
                    child: isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan Perubahan'),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme Mode Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeCard extends ConsumerWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _ThemeOption(
            label: 'Ikuti Sistem',
            subtitle: 'Mengikuti pengaturan perangkat',
            icon: Icons.brightness_auto_rounded,
            mode: ThemeMode.system,
            currentMode: currentMode,
            onChanged: (mode) =>
                ref.read(themeProvider.notifier).setThemeMode(mode),
          ),
          const Divider(height: 1),
          _ThemeOption(
            label: 'Mode Terang',
            subtitle: 'Selalu menggunakan tampilan terang',
            icon: Icons.light_mode_rounded,
            mode: ThemeMode.light,
            currentMode: currentMode,
            onChanged: (mode) =>
                ref.read(themeProvider.notifier).setThemeMode(mode),
          ),
          const Divider(height: 1),
          _ThemeOption(
            label: 'Mode Gelap',
            subtitle: 'Selalu menggunakan tampilan gelap',
            icon: Icons.dark_mode_rounded,
            mode: ThemeMode.dark,
            currentMode: currentMode,
            onChanged: (mode) =>
                ref.read(themeProvider.notifier).setThemeMode(mode),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.mode,
    required this.currentMode,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final ThemeMode mode;
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = currentMode == mode;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.12)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: 2,
                ),
                color: isSelected ? colorScheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
