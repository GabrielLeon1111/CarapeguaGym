import '../../core/supabase/supabase_config.dart';
import '../models/membership_period.dart';

class PeriodRepository {
  Future<List<MembershipPeriod>> getByMember(String memberId) async {
    final rows = await supa.from('membership_periods').select().eq('member_id', memberId).order('start_date', ascending: false);
    return (rows as List).map((e) => MembershipPeriod.fromJson(e)).toList();
  }

  Future<MembershipPeriod?> getLatestForMember(String memberId) async {
    final rows = await supa.from('membership_periods').select().eq('member_id', memberId).order('end_date', ascending: false).limit(1);
    final list = rows as List;
    return list.isEmpty ? null : MembershipPeriod.fromJson(list.first);
  }

  Future<MembershipPeriod> create(MembershipPeriod period) async {
    final row = await supa.from('membership_periods').insert(period.toInsertJson()).select().single();
    return MembershipPeriod.fromJson(row);
  }

  /// Cobros dentro de un rango de fechas (por fecha de carga/creación), con filtro opcional de método de pago.
  Future<List<MembershipPeriod>> getByChargeDateRange(DateTime start, DateTime end, {String? paymentMethod}) async {
    var query = supa.from('membership_periods').select().gte('created_at', start.toIso8601String()).lt('created_at', end.toIso8601String());
    if (paymentMethod != null) {
      query = query.eq('payment_method', paymentMethod);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((e) => MembershipPeriod.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getRenewalStats(DateTime start, DateTime end) async {
    final rows = await supa.from('v_period_renewal').select().gte('end_date', start.toIso8601String().substring(0, 10)).lte('end_date', end.toIso8601String().substring(0, 10));
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// IDs de socios que tienen al menos un período "personalizado" (sin plan del
  /// catálogo). Sirve para el apartado de socios con membresía personalizada.
  /// Personalizados = sin paquete del catálogo O con entrenador de piso.
  /// (Tener entrenador implica plan personalizado, y sirve para "preparar rutina".)
  Future<Set<String>> getCustomMemberIds() async {
    final rows = await supa.from('membership_periods').select('member_id').or('plan_id.is.null,has_trainer.is.true');
    return (rows as List).map((e) => e['member_id'] as String).toSet();
  }

  Future<List<Map<String, dynamic>>> getLateRenewalRanking() async {
    final rows = await supa.from('v_member_late_renewals').select('member_id, full_name, late_renewals_count').gt('late_renewals_count', 0).order('late_renewals_count', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
