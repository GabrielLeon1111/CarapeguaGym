import 'package:flutter/services.dart';

import 'formatters.dart';

/// Muestra separador de miles mientras se escribe, pero el valor real
/// (accesible vía [parse]) siempre es un entero plano sin formato.
class ThousandsInputFormatter extends TextInputFormatter {
  /// Límite de dígitos: evita desbordar `int` si alguien pega un número enorme.
  static const int maxDigits = 12;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    if (digits.length > maxDigits) return oldValue;
    final value = int.parse(digits);
    final formatted = thousandsFormat.format(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static int parse(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits.length > maxDigits ? digits.substring(0, maxDigits) : digits) ?? 0;
  }
}
