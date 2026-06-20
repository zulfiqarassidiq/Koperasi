import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/user_profile_model.dart';
import '../presentation/auth/auth_providers.dart';
import '../presentation/auth/change_password_page.dart';
import '../presentation/auth/create_koperasi_page.dart';
import '../presentation/auth/forgot_password_page.dart';
import '../presentation/auth/login_page.dart';
import '../presentation/auth/register_page.dart';
import '../presentation/dashboard/dashboard_page.dart';
import '../presentation/kategori/kategori_page.dart';
import '../presentation/laporan/laporan_page.dart';
import '../presentation/pengeluaran/pengeluaran_page.dart';
import '../presentation/produk/produk_detail_page.dart';
import '../presentation/produk/produk_form_page.dart';
import '../presentation/produk/produk_page.dart';
import '../presentation/settings/settings_page.dart';
import '../presentation/splash_page.dart';
import '../presentation/stok/stok_detail_page.dart';
import '../presentation/stok/stok_form_page.dart';
import '../presentation/stok/stok_page.dart';
import '../presentation/transaksi/transaksi_detail_page.dart';
import '../presentation/transaksi/transaksi_history_page.dart';
import '../presentation/transaksi/transaksi_page.dart';
import '../presentation/user_management/user_management_page.dart';
import 'app_routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route sets (untuk redirect logic)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Route permission map (role → disallowed route prefixes)
// ─────────────────────────────────────────────────────────────────────────────

/// Route yang tidak boleh diakses oleh Kasir.
/// Kasir BOLEH: transaksi, produk (CRUD), kategori (CRUD), stok (CRUD), settings (akun)
/// Kasir TIDAK BOLEH: user management, pengeluaran, laporan
const _kasirBlockedRoutes = {
  AppRoutes.userManagement,
  AppRoutes.pengeluaran,
  AppRoutes.laporan,
};

/// Cek apakah route diblokir untuk role kasir.
bool _isBlockedForKasir(String location) {
  return _kasirBlockedRoutes.any(
    (r) => location == r || location.startsWith('$r/'),
  );
}

/// Route yang tidak perlu autentikasi.
const _publicRoutes = {
  AppRoutes.splash,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
  AppRoutes.changePassword,
};

/// Route onboarding (login tapi belum punya koperasi).
const _onboardingRoutes = {
  AppRoutes.createKoperasi,
};

// ─────────────────────────────────────────────────────────────────────────────
// Router Provider
// ─────────────────────────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final refreshListenable = AuthRouteRefresh(authRepository.authStateChanges);

  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      // FIX: Mencegah GoRouter memotong navigasi saat proses Auth sedang berjalan
      final authState = ref.read(authControllerProvider);
      if (authState.isLoading) return null;

      final session = authRepository.currentSession;
      final isAuthenticated = session != null;
      final location = state.matchedLocation;

      final isSplash = location == AppRoutes.splash;
      final isPublic = _publicRoutes.contains(location);
      final isOnboarding = _onboardingRoutes.contains(location);

      // ── Splash ────────────────────────────────────────────────────────────
      if (isSplash) {
        if (!isAuthenticated) return AppRoutes.login;

        // Cek apakah user sudah punya koperasi
        final profile = await authRepository.getCurrentProfile();
        if (profile == null || !profile.hasKoperasi) {
          return AppRoutes.createKoperasi;
        }
        return AppRoutes.dashboard;
      }

      // ── Tidak terautentikasi ──────────────────────────────────────────────
      if (!isAuthenticated) {
        if (isPublic) return null; // boleh akses public routes
        return AppRoutes.login; // redirect ke login
      }

      // ── Sudah terautentikasi ──────────────────────────────────────────────

      // Jika di halaman login/register, redirect ke tempat yang sesuai
      if (location == AppRoutes.login || location == AppRoutes.register) {
        final profile = await authRepository.getCurrentProfile();
        if (profile == null || !profile.hasKoperasi) {
          return AppRoutes.createKoperasi;
        }
        return AppRoutes.dashboard;
      }

      // Jika di halaman onboarding tapi sudah punya koperasi → dashboard
      if (isOnboarding) {
        final profile = await authRepository.getCurrentProfile();
        if (profile != null && profile.hasKoperasi) {
          return AppRoutes.dashboard;
        }
        return null; // tetap di create-koperasi
      }

      // Jika di halaman app tapi belum punya koperasi → onboarding
      if (!isPublic && !isOnboarding) {
        final profile = await authRepository.getCurrentProfile();
        if (profile != null && !profile.hasKoperasi) {
          return AppRoutes.createKoperasi;
        }

        // ── RBAC: Kasir route guard ──────────────────────────────────────
        if (profile != null && profile.role == UserRole.kasir) {
          if (_isBlockedForKasir(location)) {
            return AppRoutes.dashboard;
          }
        }
      }

      return null; // tidak perlu redirect
    },
    routes: [
      // ── Splash ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),

      // ── Auth & Onboarding ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.createKoperasi,
        builder: (context, state) => const CreateKoperasiPage(),
      ),

      // ── Main App ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.produk,
        builder: (context, state) => const ProdukPage(),
      ),
      GoRoute(
        path: AppRoutes.produkCreate,
        builder: (context, state) => const ProdukFormPage(),
      ),
      GoRoute(
        path: AppRoutes.produkEdit,
        builder: (context, state) {
          return ProdukFormPage(productId: state.pathParameters['id']);
        },
      ),
      GoRoute(
        path: AppRoutes.produkDetail,
        builder: (context, state) {
          return ProdukDetailPage(
              productId: state.pathParameters['id'] ?? '');
        },
      ),
      GoRoute(
        path: AppRoutes.kategori,
        builder: (context, state) => const KategoriPage(),
      ),
      GoRoute(
        path: AppRoutes.stok,
        builder: (context, state) => const StokPage(),
      ),
      GoRoute(
        path: AppRoutes.stokCreate,
        builder: (context, state) => const StokFormPage(),
      ),
      GoRoute(
        path: AppRoutes.stokDetail,
        builder: (context, state) {
          return StokDetailPage(stockId: state.pathParameters['id'] ?? '');
        },
      ),
      GoRoute(
        path: AppRoutes.transaksi,
        builder: (context, state) => const TransaksiPage(),
      ),
      GoRoute(
        path: AppRoutes.transaksiHistory,
        builder: (context, state) => const TransaksiHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.transaksiDetail,
        builder: (context, state) {
          return TransaksiDetailPage(
            transactionId: state.pathParameters['id'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.pengeluaran,
        builder: (context, state) => const PengeluaranPage(),
      ),
      GoRoute(
        path: AppRoutes.laporan,
        builder: (context, state) => const LaporanPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.userManagement,
        builder: (context, state) => const UserManagementPage(),
      ),
    ],
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Auth Route Refresh Notifier
// ─────────────────────────────────────────────────────────────────────────────
class AuthRouteRefresh extends ChangeNotifier {
  AuthRouteRefresh(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
