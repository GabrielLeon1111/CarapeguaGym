import '../../core/supabase/supabase_config.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  Future<AppSettings> get() async {
    final row = await supa.from('app_settings').select().eq('id', true).single();
    return AppSettings.fromJson(row);
  }

  Future<AppSettings> update(AppSettings settings) async {
    final row = await supa.from('app_settings').update(settings.toUpdateJson()).eq('id', true).select().single();
    return AppSettings.fromJson(row);
  }
}
