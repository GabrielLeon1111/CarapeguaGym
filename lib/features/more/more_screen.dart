import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/ui_feedback.dart';
import '../../providers/repository_providers.dart';
import '../legal/legal_screens.dart';
import '../members/members_screen.dart';
import '../memberships/memberships_screen.dart';
import '../plans/plans_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../stock/inventory_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Widget _iconBadge(IconData icon, Color color) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
    child: Icon(icon, color: color, size: 20),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ClipOval(child: Image.asset('assets/images/logo.jpeg', width: 88, height: 88, fit: BoxFit.cover)),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _iconBadge(Icons.people_rounded, const Color(0xFF2563EB)),
              title: const Text('Socios'),
              subtitle: const Text('Cargar, buscar y ver personalizados'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembersScreen())),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _iconBadge(Icons.card_membership_rounded, const Color(0xFF0D9488)),
              title: const Text('Membresías'),
              subtitle: const Text('Elegí un paquete y cobralo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipsScreen())),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _iconBadge(Icons.list_alt_rounded, const Color(0xFF2563EB)),
              title: const Text('Catálogo de planes'),
              subtitle: const Text('Crear y editar los paquetes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen())),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _iconBadge(Icons.inventory_2_rounded, const Color(0xFFDB2777)),
              title: const Text('Inventario'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _iconBadge(Icons.insert_chart_rounded, const Color(0xFF9333EA)),
              title: const Text('Reportes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _iconBadge(Icons.settings_rounded, const Color(0xFF16A34A)),
              title: const Text('Configuración'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 16, 4),
            child: Text(
              'Legal',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _iconBadge(Icons.privacy_tip_rounded, const Color(0xFF16A34A)),
              title: const Text('Política de privacidad'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _iconBadge(Icons.description_rounded, const Color(0xFF111111)),
              title: const Text('Términos y condiciones'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _iconBadge(Icons.logout_rounded, Colors.red),
              title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text('¿Seguro que querés cerrar sesión?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ref.read(authRepositoryProvider).signOut();
                  } catch (_) {
                    if (context.mounted) showError(context, 'No se pudo cerrar sesión. Revisá la conexión e intentá de nuevo.');
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
