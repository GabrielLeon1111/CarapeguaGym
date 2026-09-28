import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feedback.dart';
import '../../data/models/plan.dart';
import '../../providers/repository_providers.dart';
import '../charge/charge_form_tab.dart';
import '../plans/plans_screen.dart';

/// Paquetes activos disponibles para cobrar.
final membershipPackagesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(planRepositoryProvider).getAll(activeOnly: true);
});

/// Panel de Membresías: elegís un paquete y lo cobrás. La creación/edición de
/// paquetes vive en "Catálogo de planes".
class MembershipsScreen extends ConsumerWidget {
  const MembershipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(membershipPackagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Membresías')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(membershipPackagesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(
            message: friendlyError(e, action: 'cargar los paquetes'),
            onRetry: () => ref.invalidate(membershipPackagesProvider),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.card_membership, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Todavía no hay paquetes activos.', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'Creá los paquetes en el catálogo para poder cobrarlos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen())),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Ir al catálogo de planes'),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Text('Elegí el paquete a cobrar', style: TextStyle(color: Colors.grey)),
                ),
                ...plans.map((p) => _PackageCard(plan: p)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Plan plan;
  const _PackageCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: scheme.primaryContainer, child: const Icon(Icons.card_membership)),
        title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${plan.daysPerWeek} días/semana'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatGs(plan.price), style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('Cobrar ›', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MembershipChargeScreen(plan: plan))),
      ),
    );
  }
}

/// Pantalla de cobro para un paquete ya elegido: solo falta el socio.
class MembershipChargeScreen extends StatelessWidget {
  final Plan plan;
  const MembershipChargeScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cobrar membresía')),
      body: ChargeFormTab(preselectedPlan: plan),
    );
  }
}
