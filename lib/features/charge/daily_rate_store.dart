import '../../core/supabase/supabase_config.dart';

/// Guarda el "precio del pase del día" en la base (tabla app_settings), para
/// que quede persistente y compartido entre dispositivos. Se reutiliza en cada
/// cobro y se puede editar desde el Catálogo de planes.
class DailyRateStore {
  Future<int?> get() async {
    final row = await supa.from('app_settings').select('daily_pass_price').eq('id', true).single();
    final v = row['daily_pass_price'];
    return v == null ? null : (v as num).toInt();
  }

  Future<void> set(int amount) async {
    await supa.from('app_settings').update({'daily_pass_price': amount}).eq('id', true);
  }
}
