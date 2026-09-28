import '../../core/supabase/supabase_config.dart';
import '../models/plan.dart';

class PlanRepository {
  Future<List<Plan>> getAll({bool activeOnly = false}) async {
    final query = supa.from('plans').select();
    final rows = activeOnly ? await query.eq('active', true).order('days_per_week') : await query.order('days_per_week');
    return (rows as List).map((e) => Plan.fromJson(e)).toList();
  }

  Future<Plan> create(Plan plan) async {
    final row = await supa.from('plans').insert(plan.toInsertJson()).select().single();
    return Plan.fromJson(row);
  }

  Future<Plan> update(Plan plan) async {
    final row = await supa.from('plans').update(plan.toInsertJson()).eq('id', plan.id).select().single();
    return Plan.fromJson(row);
  }

  Future<void> setActive(String id, bool active) async {
    await supa.from('plans').update({'active': active}).eq('id', id);
  }
}
