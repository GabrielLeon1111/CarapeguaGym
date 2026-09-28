import '../../core/supabase/supabase_config.dart';
import '../../core/utils/validators.dart';
import '../models/member.dart';
import '../models/member_status.dart';

class MemberRepository {
  Future<List<Member>> getAll({bool includeDeleted = false}) async {
    final query = supa.from('members').select();
    final rows = includeDeleted ? await query.order('full_name') : await query.isFilter('deleted_at', null).order('full_name');
    return (rows as List).map((e) => Member.fromJson(e)).toList();
  }

  Future<List<Member>> search(String term) async {
    // El término se sanea: una coma o paréntesis podría alterar el filtro `or`.
    final safe = sanitizeSearchTerm(term);
    if (safe.isEmpty) return [];
    final rows = await supa.from('members').select().isFilter('deleted_at', null).or('full_name.ilike.%$safe%,dni.ilike.%$safe%').order('full_name').limit(30);
    return (rows as List).map((e) => Member.fromJson(e)).toList();
  }

  /// Socio activo (no dado de baja) con ese DNI, excluyendo opcionalmente uno.
  Future<Member?> findByDni(String dni, {String? excludeId}) async {
    var query = supa.from('members').select().isFilter('deleted_at', null).eq('dni', dni);
    if (excludeId != null) query = query.neq('id', excludeId);
    final rows = await query.limit(1);
    final list = rows as List;
    return list.isEmpty ? null : Member.fromJson(list.first);
  }

  Future<Member> getById(String id) async {
    final row = await supa.from('members').select().eq('id', id).single();
    return Member.fromJson(row);
  }

  Future<Member> create(Member member) async {
    final row = await supa.from('members').insert(member.toInsertJson()).select().single();
    return Member.fromJson(row);
  }

  Future<Member> update(Member member) async {
    final row = await supa.from('members').update(member.toInsertJson()).eq('id', member.id).select().single();
    return Member.fromJson(row);
  }

  Future<void> setFrozen(String id, bool frozen) async {
    await supa.from('members').update({'frozen': frozen}).eq('id', id);
  }

  Future<void> softDelete(String id) async {
    await supa.from('members').update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<List<MemberStatus>> getStatuses() async {
    final rows = await supa.from('v_member_status').select();
    return (rows as List).map((e) => MemberStatus.fromJson(e)).toList();
  }

  Future<MemberStatus> getStatusFor(String memberId) async {
    final row = await supa.from('v_member_status').select().eq('member_id', memberId).single();
    return MemberStatus.fromJson(row);
  }
}
