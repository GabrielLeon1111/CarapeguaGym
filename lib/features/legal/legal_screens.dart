import 'package:flutter/material.dart';

/// Texto legal simple. Es una base general; conviene que un profesional la
/// revise antes de usarla con datos reales de clientes.
class _LegalScaffold extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;
  const _LegalScaffold({required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Última actualización: 24/09/2026', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 16),
          for (final (heading, body) in sections) ...[
            Text(heading, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Política de privacidad',
      sections: [
        (
          'Qué datos guardamos',
          'La app guarda los datos que el gimnasio carga para administrar su negocio: nombre y apellido de los socios y, de forma opcional, cédula, teléfono, email, IMEI, foto, y el historial de cobros, membresías y ventas de productos.',
        ),
        (
          'Para qué los usamos',
          'Los datos se usan únicamente para gestionar las membresías, cobros, inventario y avisos de vencimiento del propio gimnasio. No se venden ni se comparten con terceros con fines publicitarios.',
        ),
        (
          'Dónde se guardan',
          'La información se almacena de forma segura en el servicio de base de datos del gimnasio (Supabase). El acceso está protegido con usuario y contraseña, y opcionalmente con desbloqueo biométrico en el dispositivo.',
        ),
        (
          'Responsable de los datos',
          'El gimnasio es el responsable de los datos de sus socios. Debe cargar y conservar solo la información necesaria y contar con el consentimiento del socio cuando corresponda.',
        ),
        (
          'Derechos del socio',
          'Cualquier socio puede pedir al gimnasio ver, corregir o eliminar sus datos personales. El gimnasio puede dar de baja a un socio, lo que lo oculta de los listados conservando el historial contable.',
        ),
        ('Contacto', 'Ante dudas sobre el manejo de datos, el socio puede comunicarse directamente con la administración del gimnasio.'),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Términos y condiciones',
      sections: [
        (
          'Uso de la aplicación',
          'Esta aplicación es una herramienta de administración interna para el gimnasio (socios, cobros, membresías e inventario). Su uso está destinado al personal autorizado del gimnasio.',
        ),
        ('Cuenta y acceso', 'El acceso se realiza con una cuenta de administrador. El titular es responsable de mantener en secreto su contraseña y de las operaciones realizadas desde su cuenta.'),
        (
          'Cobros y montos',
          'Los precios, cobros, descuentos y saldos que se muestran son los que el propio gimnasio carga. La app ayuda a registrarlos y calcularlos, pero la exactitud de los importes es responsabilidad de quien los ingresa.',
        ),
        (
          'Anulaciones',
          'Las ventas y cobros pueden anularse desde la app. Al anular, se revierte la operación (por ejemplo, se devuelve el stock). Es responsabilidad del usuario verificar cada anulación antes de confirmarla.',
        ),
        ('Disponibilidad', 'La app necesita conexión a internet para funcionar. Se procura la mayor disponibilidad posible, pero no se garantiza un servicio ininterrumpido ni libre de errores.'),
        ('Limitación de responsabilidad', 'La aplicación se entrega "tal cual". El gimnasio es responsable del uso que hace de la herramienta y de la información que registra en ella.'),
      ],
    );
  }
}
