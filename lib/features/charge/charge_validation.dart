import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Resultado de revisar un cobro antes de guardarlo.
/// - [errors]: impiden cobrar; hay que corregirlos.
/// - [warnings]: cosas raras que se muestran en la confirmación final.
class ChargeCheck {
  final List<String> errors;
  final List<String> warnings;
  const ChargeCheck(this.errors, this.warnings);
  bool get ok => errors.isEmpty;
}

ChargeCheck checkCharge({
  required bool memberSelected,
  required String searchText,
  required bool memberFrozen,
  required bool catalogMode,
  required bool planSelected,
  int? listPrice,
  required int basePrice,
  required bool hasTrainer,
  required int trainerPrice,
  required DateTime startDate,
  DateTime? previousEndDate,
  required DateTime today,
}) {
  final errors = <String>[];
  final warnings = <String>[];
  final t = dateOnly(today);
  final start = dateOnly(startDate);

  if (!memberSelected) {
    errors.add(
      searchText.trim().isEmpty
          ? 'Falta elegir el socio: escribí su nombre o DNI arriba y tocá su nombre en la lista.'
          : 'Escribiste "${searchText.trim()}" pero no elegiste a nadie. Tocá el nombre del socio en la lista (o registralo si es nuevo).',
    );
  }
  if (catalogMode && !planSelected) {
    errors.add('Elegiste "Del catálogo" pero no seleccionaste ningún plan. Elegí un plan o cambiá a "Personalizado".');
  }
  final priceError = Validators.amount(basePrice, field: 'el precio de la cuota');
  if (priceError != null) errors.add(priceError);
  if (hasTrainer) {
    if (trainerPrice <= 0) {
      errors.add('Activaste "entrenador de piso" pero el costo está vacío. Ingresá cuánto cuesta o desactivá la opción.');
    } else {
      final trainerError = Validators.amount(trainerPrice, field: 'el costo del entrenador');
      if (trainerError != null) errors.add(trainerError);
    }
  }
  if (start.isBefore(DateTime(t.year - 1, t.month, t.day)) || start.isAfter(DateTime(t.year + 1, t.month, t.day))) {
    errors.add('La fecha de inicio (${_dateFmt.format(start)}) está a más de un año de hoy. Revisá el año.');
  }

  if (errors.isNotEmpty) return ChargeCheck(errors, warnings);

  if (memberFrozen) {
    warnings.add('El socio está CONGELADO. Acordate de descongelarlo después.');
  }
  if (basePrice < Validators.suspiciouslyLowAmount) {
    warnings.add('El precio (${formatGs(basePrice)}) es muy bajo. ¿Te faltaron ceros?');
  }
  if (catalogMode && listPrice != null && basePrice > listPrice) {
    warnings.add('Estás cobrando ${formatGs(basePrice)}, más que el precio de lista del plan (${formatGs(listPrice)}).');
  }
  if (previousEndDate != null && start.isBefore(dateOnly(previousEndDate))) {
    warnings.add('Este socio YA TIENE PAGO hasta el ${_dateFmt.format(previousEndDate)}. Si el nuevo período empieza el ${_dateFmt.format(start)}, le cobrás días que ya pagó.');
  }
  if (start.isBefore(t.subtract(const Duration(days: 31)))) {
    warnings.add('La fecha de inicio es de hace más de un mes (${_dateFmt.format(start)}).');
  } else if (start.isAfter(t.add(const Duration(days: 31)))) {
    warnings.add('La fecha de inicio es dentro de más de un mes (${_dateFmt.format(start)}).');
  }
  return ChargeCheck(errors, warnings);
}

/// Fecha de inicio sugerida: si el socio todavía tiene días pagos, el nuevo
/// período arranca cuando vence el anterior; si no, hoy.
DateTime suggestedStartDate(DateTime? previousEndDate, DateTime today) {
  final t = dateOnly(today);
  if (previousEndDate != null && !dateOnly(previousEndDate).isBefore(t)) return dateOnly(previousEndDate);
  return t;
}
