enum MemberStatusKind { activo, vencido, congelado, sinPeriodo }

class MemberStatus {
  final String memberId;
  final String fullName;
  final String? dni;
  final String? phone;
  final String? photoUrl;
  final bool frozen;
  final String? latestPeriodId;
  final DateTime? endDate;
  final int? daysPerWeek;
  final bool? hasTrainer;
  final int? latestAmount;
  final int? daysOverdue;
  final MemberStatusKind status;

  MemberStatus({
    required this.memberId,
    required this.fullName,
    this.dni,
    this.phone,
    this.photoUrl,
    required this.frozen,
    this.latestPeriodId,
    this.endDate,
    this.daysPerWeek,
    this.hasTrainer,
    this.latestAmount,
    this.daysOverdue,
    required this.status,
  });

  factory MemberStatus.fromJson(Map<String, dynamic> json) => MemberStatus(
    memberId: json['member_id'] as String,
    fullName: json['full_name'] as String,
    dni: json['dni'] as String?,
    phone: json['phone'] as String?,
    photoUrl: json['photo_url'] as String?,
    frozen: json['frozen'] as bool,
    latestPeriodId: json['latest_period_id'] as String?,
    endDate: json['end_date'] == null ? null : DateTime.parse(json['end_date'] as String),
    daysPerWeek: json['days_per_week'] as int?,
    hasTrainer: json['has_trainer'] as bool?,
    latestAmount: json['latest_amount'] == null ? null : (json['latest_amount'] as num).toInt(),
    daysOverdue: json['days_overdue'] as int?,
    status: switch (json['status'] as String) {
      'activo' => MemberStatusKind.activo,
      'vencido' => MemberStatusKind.vencido,
      'congelado' => MemberStatusKind.congelado,
      _ => MemberStatusKind.sinPeriodo,
    },
  );
}
