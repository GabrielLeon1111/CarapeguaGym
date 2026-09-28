import 'package:intl/intl.dart';

final guaraniFormat = NumberFormat.currency(locale: 'es_PY', symbol: 'Gs. ', decimalDigits: 0);
final thousandsFormat = NumberFormat.decimalPattern('es_PY');

String formatGs(int amount) => guaraniFormat.format(amount);
