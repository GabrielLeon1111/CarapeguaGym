import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui_feedback.dart';
import 'validators.dart';

/// Abre el chat de WhatsApp del socio, avisando claramente si falta el
/// teléfono o si está mal cargado.
Future<void> openWhatsApp(BuildContext context, String? phone, {String? memberName}) async {
  if (phone == null || phone.trim().isEmpty) {
    showWarning(context, '${memberName ?? 'Este socio'} no tiene teléfono cargado. Agregalo desde "Editar socio".');
    return;
  }
  final number = whatsappNumber(phone);
  if (number == null) {
    showWarning(context, 'El teléfono "$phone" parece incompleto. Corregilo desde "Editar socio".');
    return;
  }
  try {
    final ok = await launchUrl(Uri.parse('https://wa.me/$number'), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showError(context, 'No se pudo abrir WhatsApp. ¿Está instalado en este teléfono?');
  } catch (_) {
    if (context.mounted) showError(context, 'No se pudo abrir WhatsApp. ¿Está instalado en este teléfono?');
  }
}
