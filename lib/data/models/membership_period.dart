import 'payment_method.dart';

class MembershipPeriod {
  final String id;
  final String memberId;
  final String? planId;
  final int daysPerWeek;
  final int basePrice;
  final int? listPrice;
  final bool hasTrainer;
  final int trainerPrice;
  final int totalAmount;
  final PaymentMethod paymentMethod;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  MembershipPeriod({
    required this.id,
    required this.memberId,
    this.planId,
    required this.daysPerWeek,
    required this.basePrice,
    this.listPrice,
    required this.hasTrainer,
    required this.trainerPrice,
    required this.totalAmount,
    required this.paymentMethod,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  int get discountAmount => (listPrice ?? basePrice) - basePrice;

  factory MembershipPeriod.fromJson(Map<String, dynamic> json) => MembershipPeriod(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    planId: json['plan_id'] as String?,
    daysPerWeek: json['days_per_week'] as int,
    basePrice: (json['base_price'] as num).toInt(),
    listPrice: json['list_price'] == null ? null : (json['list_price'] as num).toInt(),
    hasTrainer: json['has_trainer'] as bool,
    trainerPrice: (json['trainer_price'] as num).toInt(),
    totalAmount: (json['total_amount'] as num).toInt(),
    paymentMethod: PaymentMethod.fromDb(json['payment_method'] as String),
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toInsertJson() => {
    'member_id': memberId,
    'plan_id': planId,
    'days_per_week': daysPerWeek,
    'base_price': basePrice,
    'list_price': listPrice,
    'has_trainer': hasTrainer,
    'trainer_price': trainerPrice,
    'payment_method': paymentMethod.name,
    'start_date': startDate.toIso8601String().substring(0, 10),
    'end_date': endDate.toIso8601String().substring(0, 10),
  };
}
