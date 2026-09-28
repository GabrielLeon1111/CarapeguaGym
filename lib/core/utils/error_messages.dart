import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce cualquier error técnico a un mensaje que entienda alguien que no
/// sabe de sistemas. Nunca muestra detalles internos (SQL, stack traces, etc.).
String friendlyError(Object error, {String action = 'guardar'}) {
  if (error is AuthException) return friendlyAuthError(error);
  if (error is SocketException || error is TimeoutException || error is HttpException) {
    return 'No hay conexión a internet (o es muy lenta). Revisá el wifi o los datos y volvé a intentar.';
  }
  if (error is StorageException) {
    final code = error.statusCode ?? '';
    if (code == '413') return 'La foto es demasiado pesada. Elegí una más liviana.';
    return 'No se pudo subir la foto. Probá con otra imagen o intentá de nuevo.';
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final msg = error.message.toLowerCase();
    if (code == '23505') {
      if (msg.contains('dni')) return 'Ya hay otro socio registrado con ese DNI.';
      if (msg.contains('name')) return 'Ya existe un registro con ese nombre. Usá un nombre distinto.';
      return 'Ese dato ya está registrado. Revisá que no lo estés cargando dos veces.';
    }
    if (code == '23514' || code == '22003') return 'Algún valor está fuera de lo permitido (por ejemplo, un monto negativo o demasiado grande).';
    if (code == '23503') return 'No se puede hacer porque está relacionado con otros registros.';
    if (code == '42501' || code == 'PGRST301' || msg.contains('jwt')) {
      return 'Tu sesión expiró. Cerrá sesión y volvé a entrar.';
    }
    if (code == 'PGRST116') return 'No se encontró el registro. Puede que alguien lo haya borrado. Actualizá la pantalla.';
    if (msg.contains('servicios') || msg.contains('stock') || msg.contains('servings')) {
      return 'No hay stock suficiente para esa venta.';
    }
    return 'No se pudo $action. Intentá de nuevo en unos segundos.';
  }
  if (error is FormatException) return 'Hay un número mal escrito. Revisá los montos y cantidades.';
  final text = error.toString().toLowerCase();
  if (text.contains('failed host lookup') || text.contains('connection') || text.contains('network')) {
    return 'No hay conexión a internet (o es muy lenta). Revisá el wifi o los datos y volvé a intentar.';
  }
  return 'Ocurrió un problema al $action. Intentá de nuevo.';
}

String friendlyAuthError(AuthException e) {
  final msg = e.message.toLowerCase();
  final code = e.code ?? '';
  if (code == 'invalid_credentials' || msg.contains('invalid login credentials')) {
    return 'Email o contraseña incorrectos. Revisá que estén bien escritos (mayúsculas y minúsculas cuentan).';
  }
  if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
    return 'Este email todavía no fue confirmado. Revisá tu bandeja de entrada.';
  }
  if (code == 'over_request_rate_limit' || code == 'over_email_send_rate_limit' || msg.contains('rate limit') || e.statusCode == '429') {
    return 'Demasiados intentos seguidos. Esperá unos minutos y volvé a probar.';
  }
  if (code == 'user_banned') return 'Este usuario está bloqueado. Contactá al administrador.';
  if (msg.contains('network') || msg.contains('socket')) {
    return 'No hay conexión a internet. Revisá el wifi o los datos.';
  }
  return 'No se pudo iniciar sesión. Revisá tus datos e intentá de nuevo.';
}
