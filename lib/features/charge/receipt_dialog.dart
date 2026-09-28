import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/membership_period.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

class ReceiptDialog extends StatelessWidget {
  final MembershipPeriod period;
  final String memberName;
  const ReceiptDialog({super.key, required this.period, required this.memberName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
      title: const Text('Cobro registrado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Socio', memberName),
          _row('Días por semana', '${period.daysPerWeek}'),
          if (period.hasTrainer) _row('Entrenador de piso', formatGs(period.trainerPrice)),
          _row('Método de pago', period.paymentMethod.label),
          _row('Período', '${_dateFmt.format(period.startDate)} - ${_dateFmt.format(period.endDate)}'),
          const Divider(),
          _row('Total', formatGs(period.totalAmount), bold: true),
        ],
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo'))],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: bold ? null : Colors.grey)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ],
    ),
  );
}
