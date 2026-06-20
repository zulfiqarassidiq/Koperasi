import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'core/config/app_locale.dart';
import 'services/supabase_service.dart';

Future<ProviderContainer> bootstrap({
  List<Override> overrides = const [],
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.load();
  await _initializeIndonesianLocale();
  await SupabaseService.initialize();

  final container = ProviderContainer(overrides: overrides);
  return container;
}

Future<void> _initializeIndonesianLocale() => AppLocale.initialize();
