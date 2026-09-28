/// Validaciones de formularios. Cada función devuelve `null` si el valor es
/// válido, o un mensaje en lenguaje simple que explica exactamente qué está
/// mal y cómo corregirlo.
class Validators {
  Validators._();

  /// Monto máximo aceptado en cualquier campo de dinero (evita ceros de más).
  static const int maxAmount = 100000000;

  /// Por debajo de este monto se pide confirmación (probablemente faltan ceros).
  static const int suspiciouslyLowAmount = 10000;

  static final _nameChars = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ' .\-]+$");
  static final _emailRegex = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)*\.[a-zA-Z]{2,}$');

  static String? personName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Escribí el nombre completo del socio.';
    if (v.length < 3) return 'El nombre es muy corto. Escribí nombre y apellido.';
    if (v.length > 100) return 'El nombre es muy largo (máximo 100 letras).';
    if (RegExp(r'\d').hasMatch(v)) return 'El nombre no puede tener números. ¿Pusiste el DNI en el lugar equivocado?';
    if (!_nameChars.hasMatch(v)) return 'El nombre tiene símbolos raros. Usá solo letras y espacios.';
    return null;
  }

  /// DNI / cédula opcional: solo números (se aceptan puntos, se ignoran).
  static String? dni(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final digits = v.replaceAll('.', '').replaceAll(' ', '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) return 'El DNI solo puede tener números (sin letras ni guiones).';
    if (digits.length < 5) return 'El DNI es muy corto. Revisá que esté completo.';
    if (digits.length > 10) return 'El DNI es muy largo. Revisá que no haya números de más.';
    return null;
  }

  /// Deja el DNI solo con dígitos para guardarlo siempre igual.
  static String? normalizeDni(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  static String? phone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (!RegExp(r'^[0-9+()\-\s]+$').hasMatch(v)) return 'El teléfono solo puede tener números (y opcionalmente + al inicio).';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return 'Al teléfono le faltan números. Ej: 0981 123456';
    if (digits.length > 15) return 'El teléfono tiene demasiados números. Revisalo.';
    return null;
  }

  static String? email(String? value, {bool required = false}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return required ? 'Escribí tu email.' : null;
    if (v.contains(' ')) return 'El email no puede tener espacios.';
    if (!v.contains('@')) return 'Al email le falta la "@". Ej: nombre@gmail.com';
    if (!_emailRegex.hasMatch(v)) return 'El email no parece válido. Ej: nombre@gmail.com';
    return null;
  }

  /// IMEI opcional: solo números (se aceptan espacios/guiones, se ignoran).
  static String? imei(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (RegExp(r'[a-zA-Z]').hasMatch(v)) return 'El IMEI solo puede tener números.';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 14 || digits.length > 17) return 'El IMEI debe tener entre 14 y 17 números. Revisá que esté completo.';
    return null;
  }

  static String? notes(String? value) {
    if ((value ?? '').length > 500) return 'Las notas son muy largas (máximo 500 caracteres).';
    return null;
  }

  /// Monto en guaraníes obligatorio y mayor a cero.
  static String? amount(int value, {required String field}) {
    if (value <= 0) return 'Ingresá $field (tiene que ser mayor a 0).';
    if (value > maxAmount) return '$field es demasiado alto. ¿Pusiste ceros de más?';
    return null;
  }

  /// Entero positivo dentro de un rango (cantidades, servicios, etc.).
  static String? intInRange(String? value, {required String field, int min = 1, required int max}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Completá $field.';
    final n = int.tryParse(v);
    if (n == null) return '$field tiene que ser un número entero.';
    if (n < min) return '$field tiene que ser como mínimo $min.';
    if (n > max) return '$field no puede ser mayor a $max. Revisá que esté bien escrito.';
    return null;
  }

  static String? requiredText(String? value, {required String message, int maxLength = 80}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return message;
    if (v.length > maxLength) return 'Es muy largo (máximo $maxLength caracteres).';
    return null;
  }

  /// Rango de fechas de filtros/reportes.
  static String? dateRange(DateTime from, DateTime to) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    if (f.isAfter(t)) return 'La fecha "Desde" es posterior a "Hasta". Cambiá una de las dos.';
    return null;
  }
}

/// Suma meses sin "desbordar" al mes siguiente: 31/01 + 1 mes = 28/02 (o 29/02).
DateTime addMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, date.day > lastDay ? lastDay : date.day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Convierte un teléfono local de Paraguay (0981 123456) al formato
/// internacional que necesita WhatsApp (595981123456).
String? whatsappNumber(String? phone) {
  if (phone == null) return null;
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = '595${digits.substring(1)}';
  if (digits.length < 9) return null;
  return digits;
}

/// Quita caracteres con significado especial en los filtros de PostgREST
/// (`,` `(` `)` `%` `*` `\` `:`) para que una búsqueda no pueda alterar la consulta.
String sanitizeSearchTerm(String term) {
  final cleaned = term.replaceAll(RegExp(r'[,()%*\\:"]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
}
