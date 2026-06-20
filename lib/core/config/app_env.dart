import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  const AppEnv._();

  static Future<void> load() => dotenv.load(fileName: 'assets/env/.env');

  static String get supabaseUrl => _required('SUPABASE_URL');
  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');
  static String get appEnv => dotenv.maybeGet('APP_ENV') ?? 'development';

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing required environment value: $key');
    }
    return value;
  }
}
