import 'payment_method.dart';

/// Un cobro de "pase del día": alguien que entra por un día suelto. Los datos
/// del cliente son opcionales y puede quedar enlazado a un socio ([memberId]).
class DailyPass {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? memberId;
  final int amount;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;

  DailyPass({required this.id, this.firstName, this.lastName, this.phone, this.memberId, required this.amount, required this.paymentMethod, required this.createdAt});

  String get displayName {
    final full = [firstName, lastName].where((e) => e != null && e.trim().isNotEmpty).join(' ').trim();
    return full.isEmpty ? 'Sin nombre' : full;
  }

  bool get hasClient => memberId != null || displayName != 'Sin nombre';

  factory DailyPass.fromJson(Map<String, dynamic> json) => DailyPass(
    id: json['id'] as String,
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    phone: json['phone'] as String?,
    memberId: json['member_id'] as String?,
    amount: (json['amount'] as num).toInt(),
    paymentMethod: PaymentMethod.fromDb(json['payment_method'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toInsertJson() => {'first_name': firstName, 'last_name': lastName, 'phone': phone, 'member_id': memberId, 'amount': amount, 'payment_method': paymentMethod.name};
}
