import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/user_profile_model.dart';
import '../presentation/auth/auth_providers.dart';
import '../routes/app_routes.dart';

/// Widget guard yang memproteksi konten berdasarkan role user.
///
/// Contoh penggunaan:
/// ```dart
/// RoleGuard(
///   allowedRoles: [UserRole.owner, UserRole.admin],
///   child: ManageUsersButton(),
/// )
/// ```
class RoleGuard extends ConsumerWidget {
  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  final List<UserRole> allowedRoles;
  final Widget child;

  /// Widget yang ditampilkan jika user tidak memiliki role yang sesuai.
  /// Default: SizedBox.shrink() (tidak tampil)
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);

    if (role == null) return fallback ?? const SizedBox.shrink();
    if (allowedRoles.contains(role)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Guard untuk halaman penuh – redirect ke dashboard jika tidak punya akses.
class RolePageGuard extends ConsumerWidget {
  const RolePageGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
  });

  final List<UserRole> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Gagal memuat profil.')),
      ),
      data: (profile) {
        if (profile == null || !allowedRoles.contains(profile.role)) {
          // Redirect ke dashboard setelah frame selesai render
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Anda tidak memiliki akses ke halaman ini.'),
                ),
              );
              context.go(AppRoutes.dashboard);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child;
      },
    );
  }
}
