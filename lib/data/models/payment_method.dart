enum PaymentMethod {
  efectivo,
  tarjeta,
  transferencia,
  qr;

  static PaymentMethod fromDb(String value) => PaymentMethod.values.firstWhere((e) => e.name == value);

  String get label => switch (this) {
    PaymentMethod.efectivo => 'Efectivo',
    PaymentMethod.tarjeta => 'Tarjeta',
    PaymentMethod.transferencia => 'Transferencia',
    PaymentMethod.qr => 'QR',
  };
}
