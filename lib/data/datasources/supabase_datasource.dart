import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SupabaseDatasource {
  const SupabaseDatasource(this.client);

  final SupabaseClient client;
}
