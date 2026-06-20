import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// SplashPage hanya menampilkan loading screen.
/// Redirect logic ditangani sepenuhnya oleh GoRouter redirect di app_router.dart.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.point_of_sale_rounded,
                size: 72,
                color: colors.primary,
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'Kasir POS Koperasi',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 8),
            Text(
              'Sistem Kasir Desa Terpadu',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 48),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.primary,
              ),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
