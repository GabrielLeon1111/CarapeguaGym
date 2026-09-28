import 'dart:math';

final _rand = Random.secure();

/// Genera un UUID v4 para usar como "clave de operación" (idempotencia): si un
/// guardado se reintenta con la misma clave, el servidor no lo duplica.
String newOpId() {
  final b = List<int>.generate(16, (_) => _rand.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // versión 4
  b[8] = (b[8] & 0x3f) | 0x80; // variante
  String hx(int n) => n.toRadixString(16).padLeft(2, '0');
  final s = b.map(hx).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}
