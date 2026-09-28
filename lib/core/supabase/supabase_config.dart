import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class SupabaseConfig {
  static const String url = supabaseUrl;
  static const String publishableKey = supabasePublishableKey;

  static Future<void> init() async {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }
}

SupabaseClient get supa => Supabase.instance.client;
