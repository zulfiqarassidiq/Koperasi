import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/dashboard_stats_model.dart';

import '../../data/models/user_profile_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/profile_drawer.dart';
import '../../widgets/role_badge.dart';
import '../auth/auth_message_listener.dart';
import '../auth/auth_providers.dart';
import 'dashboard_providers.dart';
import 'widgets/dashboard_module_card.dart';
import 'widgets/dashboard_stat_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenAuthMessages(ref, context);
    final statsState = ref.watch(dashboardStatsProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final koperasi = ref.watch(currentKoperasiProvider).valueOrNull;
    final session = ref.watch(authSessionProvider).valueOrNull;

    return AppScaffold(
      title: 'Koperasi POS',
      drawer: ProfileDrawer(
        profile: profile,
        koperasi: koperasi,
      ),
      actions: [
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Profil',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.person_outline),
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(dashboardStatsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Stack(
        children: [
          const Positioned.fill(
            child: _AnimatedBackgroundPattern(),
          ),
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(dashboardStatsProvider.future),
              child: statsState.when(
                loading: () => const _DashboardLoadingState(),
                error: (error, stackTrace) => _DashboardErrorState(
                  message: _errorMessage(error),
                  onRetry: () => ref.invalidate(dashboardStatsProvider),
                ),
                data: (stats) => _DashboardContent(
                  stats: stats,
                  userName: profile?.nama.isNotEmpty == true
                      ? profile!.nama
                      : 'User',
                  email: session?.user.email ?? '-',
                  userRole: profile?.role,
                  koperasiName: koperasi?.namaKoperasi,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Gagal memuat dashboard. Silakan coba lagi.';
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.stats,
    required this.userName,
    required this.email,
    this.userRole,
    this.koperasiName,
  });

  final DashboardStatsModel stats;
  final String userName;
  final String email;
  final UserRole? userRole;
  final String? koperasiName;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HeroHeader(
                userName: userName,
                email: email,
                userRole: userRole,
                koperasiName: koperasiName,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Statistik Hari Ini',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: constraints.maxWidth >= 720 ? 300 : 200,
                mainAxisExtent: 160,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              delegate: SliverChildListDelegate([
                DashboardStatCard(
                  title: 'Transaksi',
                  value: NumberFormat.decimalPattern(AppLocale.formattingLocale)
                      .format(stats.todayTransactions),
                  icon: Icons.receipt_long_rounded,
                  color: AppTheme.accent,
                )
                    .animate(delay: 300.ms)
                    .fadeIn()
                    .scale(begin: const Offset(0.8, 0.8)),
                DashboardStatCard(
                  title: 'Penjualan',
                  value: currency.format(stats.todaySalesAmount),
                  icon: Icons.point_of_sale_rounded,
                  color: AppTheme.secondary,
                )
                    .animate(delay: 400.ms)
                    .fadeIn()
                    .scale(begin: const Offset(0.8, 0.8)),
                DashboardStatCard(
                  title: 'Pengeluaran',
                  value: currency.format(stats.todayExpenses),
                  icon: Icons.payments_rounded,
                  color: AppTheme.error,
                )
                    .animate(delay: 500.ms)
                    .fadeIn()
                    .scale(begin: const Offset(0.8, 0.8)),
              ]),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Menu Utama',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.05),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            _DashboardModules(
              isWide: constraints.maxWidth >= 720,
              userRole: userRole,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.userName,
    required this.email,
    this.userRole,
    this.koperasiName,
  });

  final String userName;
  final String email;
  final UserRole? userRole;
  final String? koperasiName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Selamat Pagi'
        : now.hour < 15
            ? 'Selamat Siang'
            : now.hour < 18
                ? 'Selamat Sore'
                : 'Selamat Malam';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white24,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (koperasiName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              koperasiName!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (userRole != null)
                RoleBadge(role: userRole!),
            ],
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeroStatItem(
                label: 'Performa Hari Ini',
                value: 'Sangat Baik',
                icon: Icons.trending_up,
              ),
              _HeroStatItem(
                label: 'Status Sistem',
                value: 'Online',
                icon: Icons.cloud_done,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatItem extends StatelessWidget {
  const _HeroStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white60, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DashboardModules extends StatelessWidget {
  const _DashboardModules({required this.isWide, this.userRole});

  final bool isWide;
  final UserRole? userRole;

  @override
  Widget build(BuildContext context) {
    final isOwnerOrAdmin =
        userRole == UserRole.owner || userRole == UserRole.admin;

    // Semua module yang tersedia
    final allItems = <(
      String title,
      IconData icon,
      String route,
      Color color,
      bool ownerAdminOnly,
    )>[
      (
        'Transaksi',
        Icons.point_of_sale_rounded,
        AppRoutes.transaksi,
        AppTheme.primary,
        false,
      ),
      (
        'Produk',
        Icons.inventory_2_rounded,
        AppRoutes.produk,
        AppTheme.secondary,
        false,
      ),
      (
        'Stok',
        Icons.add_box_rounded,
        AppRoutes.stok,
        AppTheme.warning,
        false, // kasir bisa lihat stok
      ),
      (
        'Kategori',
        Icons.category_rounded,
        AppRoutes.kategori,
        AppTheme.accent,
        false, // kasir bisa kelola kategori
      ),
      (
        'Pengeluaran',
        Icons.payments_rounded,
        AppRoutes.pengeluaran,
        AppTheme.error,
        false, // kasir sekarang bisa mengelola pengeluaran
      ),
      (
        'Laporan',
        Icons.bar_chart_rounded,
        AppRoutes.laporan,
        AppTheme.primary,
        false, // kasir bisa melihat laporan (sudah difilter by koperasi_id)
      ),
      (
        'Anggota',
        Icons.group_rounded,
        AppRoutes.userManagement,
        AppTheme.secondary,
        true,
      ),
      (
        'Settings',
        Icons.settings_rounded,
        AppRoutes.settings,
        AppTheme.secondary,
        false, // kasir bisa buka settings tapi isinya dibatasi (akun saja)
      ),
    ];

    // Filter berdasarkan role
    final items = allItems
        .where((item) => !item.$5 || isOwnerOrAdmin)
        .toList();

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        mainAxisExtent: 110,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          return DashboardModuleCard(
            title: item.$1,
            icon: item.$2,
            color: item.$4,
            onTap: () => context.go(item.$3),
          )
              .animate(delay: (700 + (index * 50)).ms)
              .fadeIn()
              .slideY(begin: 0.2, end: 0);
        },
        childCount: items.length,
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const LoadingState(message: 'Memuat dashboard...');
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBackgroundPattern extends StatelessWidget {
  const _AnimatedBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.05),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .slide(
                begin: const Offset(0, 0),
                end: const Offset(0.15, 0.15),
                duration: 15000.ms,
                curve: Curves.easeInOutSine,
              )
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.15, 1.15),
                duration: 20000.ms,
                curve: Curves.easeInOutSine,
              ),
        ),
        Positioned(
          bottom: 100,
          right: -100,
          child: Container(
            width: 450,
            height: 450,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.04),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .slide(
                begin: const Offset(0, 0),
                end: const Offset(-0.1, -0.15),
                duration: 18000.ms,
                curve: Curves.easeInOutSine,
              )
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.2, 1.2),
                duration: 25000.ms,
                curve: Curves.easeInOutSine,
              ),
        ),
      ],
    );
  }
}

