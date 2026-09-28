import 'package:flutter/material.dart';

import '../../../data/models/member_status.dart';

class StatusChip extends StatelessWidget {
  final MemberStatusKind status;
  final int? daysOverdue;

  const StatusChip({super.key, required this.status, this.daysOverdue});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      MemberStatusKind.activo => (Colors.green, 'Activo'),
      MemberStatusKind.vencido => (Colors.red, daysOverdue != null && daysOverdue! > 0 ? 'Vencido (${daysOverdue}d)' : 'Vencido'),
      MemberStatusKind.congelado => (Colors.blueGrey, 'Congelado'),
      MemberStatusKind.sinPeriodo => (Colors.orange, 'Sin período'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
