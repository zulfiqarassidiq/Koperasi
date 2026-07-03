import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/user_invite_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/role_guard.dart';
import '../auth/auth_providers.dart';
import '../../core/theme/app_theme.dart';
import 'user_management_providers.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() =>
      _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _listenMessages() {
    ref.listen<UserMgmtState>(userMgmtControllerProvider, (_, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.errorMessage != null) {
        messenger.showSnackBar(SnackBar(
          content: Text(next.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
        ref.read(userMgmtControllerProvider.notifier).clearMessages();
      }
      if (next.successMessage != null) {
        messenger.showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline, color: Colors.white70),
            const SizedBox(width: 10),
            Text(next.successMessage!),
          ]),
          behavior: SnackBarBehavior.floating,
        ));
        ref.read(userMgmtControllerProvider.notifier).clearMessages();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _listenMessages();
    final currentProfile = ref.watch(currentProfileProvider).valueOrNull;
    final isOwnerOrAdmin = currentProfile?.role == UserRole.owner ||
        currentProfile?.role == UserRole.admin;
    final theme = Theme.of(context);

    return RolePageGuard(
      allowedRoles: const [UserRole.owner, UserRole.admin],
      child: AppScaffold(
        title: 'Manajemen Anggota',
        showBackButton: true,
        actions: [
          if (isOwnerOrAdmin)
            IconButton(
              tooltip: 'Undang Anggota',
              icon: const Icon(Icons.person_add_rounded),
              onPressed: () => _showInviteDialog(context),
            ),
        ],
        child: Column(
          children: [
            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: theme.colorScheme.primary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Anggota'),
                  Tab(text: 'Undangan'),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MembersTab(isOwnerOrAdmin: isOwnerOrAdmin, currentUserId: currentProfile?.id),
                  _InvitesTab(isOwnerOrAdmin: isOwnerOrAdmin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Members
// ─────────────────────────────────────────────────────────────────────────────
class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.isOwnerOrAdmin, required this.currentUserId});

  final bool isOwnerOrAdmin;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);

    return membersAsync.when(
      loading: () => const LoadingState(message: 'Memuat daftar anggota...'),
      error: (e, _) => const EmptyState(
        icon: Icons.error_outline_rounded,
        message: 'Gagal memuat anggota.',
      ),
      data: (members) {
        if (members.isEmpty) {
          return const EmptyState(
            icon: Icons.group_outlined,
            message: 'Belum ada anggota koperasi.',
          );
        }
        return ListView.separated(
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _MemberTile(
            member: members[index],
            isOwnerOrAdmin: isOwnerOrAdmin,
            isCurrentUser: members[index].id == currentUserId,
          ).animate(delay: (index * 60).ms).fadeIn().slideX(begin: 0.05),
        );
      },
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.isOwnerOrAdmin,
    required this.isCurrentUser,
  });

  final UserProfileModel member;
  final bool isOwnerOrAdmin;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(userMgmtControllerProvider).isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  _roleColor(member.role).withValues(alpha: 0.15),
              child: Text(
                member.nama.isNotEmpty
                    ? member.nama[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: _roleColor(member.role),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.nama.isNotEmpty ? member.nama : '(Tanpa Nama)',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Anda',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _RoleBadge(role: member.role),
                      if (member.createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Bergabung ${DateFormat('dd MMM yyyy', 'id').format(member.createdAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions (only for owner/admin, not self, not owner member)
            if (isOwnerOrAdmin && !isCurrentUser && member.role != UserRole.owner)
              _MemberActions(
                member: member,
                isLoading: isLoading,
              ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return AppTheme.primary;
      case UserRole.admin:
        return AppTheme.secondary;
      case UserRole.kasir:
        return AppTheme.accent;
    }
  }
}

class _MemberActions extends ConsumerWidget {
  const _MemberActions({required this.member, required this.isLoading});

  final UserProfileModel member;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      enabled: !isLoading,
      icon: const Icon(Icons.more_vert_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        // Change Role
        PopupMenuItem(
          value: 'change_role',
          child: Row(
            children: [
              const Icon(Icons.manage_accounts_rounded, size: 20),
              const SizedBox(width: 10),
              Text(
                member.role == UserRole.kasir
                    ? 'Jadikan Admin'
                    : 'Jadikan Kasir',
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // Remove Member
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(
                Icons.person_remove_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 10),
              Text(
                'Keluarkan',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'change_role') {
          _showChangeRoleConfirm(context, ref);
        } else if (value == 'remove') {
          _showRemoveConfirm(context, ref);
        }
      },
    );
  }

  void _showChangeRoleConfirm(BuildContext context, WidgetRef ref) {
    final newRole =
        member.role == UserRole.kasir ? UserRole.admin : UserRole.kasir;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Role'),
        content: Text(
          'Ubah role ${member.nama} dari ${member.role.label} menjadi ${newRole.label}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(userMgmtControllerProvider.notifier).changeRole(
                    memberId: member.id,
                    newRole: newRole,
                  );
            },
            child: const Text('Ubah'),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirm(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluarkan Anggota'),
        content: Text(
          'Keluarkan ${member.nama} dari koperasi? Akun mereka tidak akan dihapus.',
        ),
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
              ref
                  .read(userMgmtControllerProvider.notifier)
                  .removeMember(member.id);
            },
            child: const Text('Keluarkan'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Invites
// ─────────────────────────────────────────────────────────────────────────────
class _InvitesTab extends ConsumerWidget {
  const _InvitesTab({required this.isOwnerOrAdmin});

  final bool isOwnerOrAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(invitesProvider);
    final isLoading = ref.watch(userMgmtControllerProvider).isLoading;

    return invitesAsync.when(
      loading: () => const LoadingState(message: 'Memuat daftar undangan...'),
      error: (e, _) => const EmptyState(
        icon: Icons.error_outline_rounded,
        message: 'Gagal memuat undangan.',
      ),
      data: (invites) {
        if (invites.isEmpty) {
          return const EmptyState(
            icon: Icons.mail_outline_rounded,
            message: 'Belum ada undangan yang dikirim.',
          );
        }
        return ListView.separated(
          itemCount: invites.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _InviteTile(
            invite: invites[index],
            canCancel: isOwnerOrAdmin,
            isLoading: isLoading,
          ).animate(delay: (index * 60).ms).fadeIn().slideX(begin: 0.05),
        );
      },
    );
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({
    required this.invite,
    required this.canCancel,
    required this.isLoading,
  });

  final UserInviteModel invite;
  final bool canCancel;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPending = invite.status == InviteStatus.pending;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isPending
                        ? AppTheme.warning
                        : AppTheme.success)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPending
                    ? Icons.schedule_rounded
                    : Icons.check_circle_rounded,
                size: 22,
                color: isPending
                    ? AppTheme.warning
                    : AppTheme.success,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.email,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _RoleBadge(role: invite.role),
                      const SizedBox(width: 8),
                      _StatusBadge(status: invite.status),
                    ],
                  ),
                  if (invite.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dikirim ${DateFormat('dd MMM yyyy, HH:mm', 'id').format(invite.createdAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Cancel button (only for pending)
            if (canCancel && isPending)
              IconButton(
                tooltip: 'Batalkan Undangan',
                onPressed: isLoading
                    ? null
                    : () => _showCancelConfirm(context, ref),
                icon: Icon(
                  Icons.cancel_outlined,
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirm(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Undangan'),
        content: Text(
            'Batalkan undangan untuk ${invite.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tidak'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(userMgmtControllerProvider.notifier)
                  .cancelInvite(invite.id);
            },
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invite Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog();

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  UserRole _selectedRole = UserRole.kasir;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(userMgmtControllerProvider.notifier).sendInvite(
          email: _emailController.text,
          role: _selectedRole,
        );

    if (success && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(userMgmtControllerProvider).isLoading;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_add_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Undang Anggota'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'email@contoh.com',
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
            ),
            const SizedBox(height: 16),
            FormField<UserRole>(
              initialValue: _selectedRole,
              builder: (field) => InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge_rounded),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UserRole>(
                    value: _selectedRole,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('Admin'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.kasir,
                        child: Text('Kasir'),
                      ),
                    ],
                    onChanged: (role) {
                      if (role != null) setState(() => _selectedRole = role);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                _selectedRole == UserRole.admin
                    ? 'Admin: akses produk, stok, transaksi, pengeluaran, laporan, user management.'
                    : 'Kasir: akses transaksi dan lihat produk/stok saja.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: isLoading ? null : _submit,
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: const Text('Kirim Undangan'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      UserRole.owner => ('Owner', AppTheme.primary),
      UserRole.admin => ('Admin', AppTheme.secondary),
      UserRole.kasir => ('Kasir', AppTheme.accent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final InviteStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InviteStatus.pending => ('Menunggu', AppTheme.warning),
      InviteStatus.accepted => ('Diterima', AppTheme.success),
      InviteStatus.rejected => ('Ditolak', AppTheme.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
