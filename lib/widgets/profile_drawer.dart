import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/koperasi_model.dart';
import '../data/models/user_profile_model.dart';
import '../presentation/auth/auth_providers.dart';
import 'role_badge.dart';

class ProfileDrawer extends ConsumerWidget {
  const ProfileDrawer({
    super.key,
    required this.profile,
    required this.koperasi,
  });

  final UserProfileModel? profile;
  final KoperasiModel? koperasi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final email = session?.user.email ?? '-';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            accountName: Text(
              profile?.nama ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimary,
              child: Text(
                (profile?.nama ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Nama Lengkap'),
            subtitle: Text(profile?.nama ?? '-'),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(email),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Role / Peran'),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: profile?.role != null
                    ? RoleBadge(role: profile!.role)
                    : const Text('-'),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Koperasi'),
            subtitle: Text(koperasi?.namaKoperasi ?? '-'),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Keluar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context); // close drawer
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
