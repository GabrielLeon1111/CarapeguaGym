import '../../core/supabase/supabase_config.dart';
import '../models/daily_pass.dart';

class DailyPassRepository {
  Future<DailyPass> create(DailyPass pass) async {
    final row = await supa.from('daily_passes').insert(pass.toInsertJson()).select().single();
    return DailyPass.fromJson(row);
  }

  /// Pases cobrados en un rango de fechas (por fecha de cobro).
  Future<List<DailyPass>> getByDateRange(DateTime start, DateTime end) async {
    final rows = await supa.from('daily_passes').select().gte('created_at', start.toIso8601String()).lt('created_at', end.toIso8601String()).order('created_at', ascending: false);
    return (rows as List).map((e) => DailyPass.fromJson(e)).toList();
  }

  /// Anula (borra) un pase del día.
  Future<void> delete(String id) async {
    await supa.from('daily_passes').delete().eq('id', id);
  }

  /// Asocia (o cambia) el cliente de un pase ya cobrado.
  Future<void> updateClient(String id, {String? memberId, String? firstName, String? lastName, String? phone}) async {
    await supa.from('daily_passes').update({'member_id': memberId, 'first_name': firstName, 'last_name': lastName, 'phone': phone}).eq('id', id);
  }
}
