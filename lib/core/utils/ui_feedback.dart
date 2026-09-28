import 'package:flutter/material.dart';

/// Mensajes consistentes en toda la app: rojo = error, naranja = advertencia,
/// verde = éxito. Siempre con ícono para que se entiendan de un vistazo.
void showError(BuildContext context, String message) => _show(context, message, Colors.red.shade700, Icons.error_outline);

void showWarning(BuildContext context, String message) => _show(context, message, Colors.orange.shade800, Icons.warning_amber_rounded);

void showSuccess(BuildContext context, String message) => _show(context, message, Colors.green.shade700, Icons.check_circle_outline);

void _show(BuildContext context, String message, Color color, IconData icon) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: Duration(milliseconds: 2500 + message.length * 40),
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

/// Pide confirmación antes de una acción importante. Devuelve `true` solo si
/// la persona tocó explícitamente el botón de confirmar.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Sí, continuar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon != null ? Icon(icon, size: 36, color: destructive ? Colors.red : Colors.orange.shade800) : null,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Caja roja inline para mostrar un error dentro de un formulario/bottom sheet
/// (donde un SnackBar quedaría tapado).
class InlineError extends StatelessWidget {
  final String? message;
  const InlineError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message!, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// Estado de error de pantalla completa con botón "Reintentar".
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
