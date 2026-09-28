import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/contact.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feedback.dart';
import '../../data/models/member.dart';
import '../../data/models/member_status.dart';
import '../../data/models/membership_period.dart';
import '../../providers/repository_providers.dart';
import '../charge/charge_screen.dart';
import 'member_form_screen.dart';
import 'widgets/status_chip.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

final memberDetailProvider = FutureProvider.autoDispose.family<Member, String>((ref, id) {
  return ref.watch(memberRepositoryProvider).getById(id);
});

final memberStatusDetailProvider = FutureProvider.autoDispose.family<MemberStatus, String>((ref, id) {
  return ref.watch(memberRepositoryProvider).getStatusFor(id);
});

final memberPeriodsProvider = FutureProvider.autoDispose.family<List<MembershipPeriod>, String>((ref, id) {
  return ref.watch(periodRepositoryProvider).getByMember(id);
});

class MemberDetailScreen extends ConsumerWidget {
  final String memberId;
  const MemberDetailScreen({super.key, required this.memberId});

  Future<void> _toggleFrozen(BuildContext context, WidgetRef ref, Member member) async {
    final freezing = !member.frozen;
    final ok = await confirmAction(
      context,
      title: freezing ? '¿Congelar a ${member.fullName}?' : '¿Descongelar a ${member.fullName}?',
      message: freezing
          ? 'Mientras esté congelado no vas a recibir avisos de vencimiento de este socio. Usalo para pausas (viaje, lesión, etc.).'
          : 'El socio vuelve a estar activo y se retoman los avisos de vencimiento.',
      confirmLabel: freezing ? 'Congelar' : 'Descongelar',
      icon: Icons.ac_unit,
    );
    if (!ok) return;
    try {
      await ref.read(memberRepositoryProvider).setFrozen(member.id, freezing);
      ref.invalidate(memberDetailProvider(memberId));
      ref.invalidate(memberStatusDetailProvider(memberId));
      if (context.mounted) showSuccess(context, freezing ? 'Socio congelado.' : 'Socio descongelado.');
    } catch (e) {
      if (context.mounted) showError(context, friendlyError(e, action: 'cambiar el estado del socio'));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final member = ref.read(memberDetailProvider(memberId)).value;
    final status = ref.read(memberStatusDetailProvider(memberId)).value;
    final name = member?.fullName ?? 'este socio';
    final activeWarning = status?.status == MemberStatusKind.activo && status?.endDate != null
        ? '\n\n⚠️ ATENCIÓN: $name tiene la membresía PAGA hasta el ${_dateFmt.format(status!.endDate!)}. ¿Seguro que querés darlo de baja?'
        : '';
    final confirmed = await confirmAction(
      context,
      title: 'Dar de baja a $name',
      message: 'El socio deja de aparecer en los listados. El historial de pagos se conserva.$activeWarning',
      confirmLabel: 'Dar de baja',
      destructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (!confirmed) return;
    try {
      await ref.read(memberRepositoryProvider).softDelete(memberId);
      if (!context.mounted) return;
      showSuccess(context, '$name fue dado de baja.');
      Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showError(context, friendlyError(e, action: 'dar de baja al socio'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMember = ref.watch(memberDetailProvider(memberId));
    final asyncStatus = ref.watch(memberStatusDetailProvider(memberId));
    final asyncPeriods = ref.watch(memberPeriodsProvider(memberId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Socio'),
        actions: [
          asyncMember.maybeWhen(
            data: (m) => IconButton(
              tooltip: 'Editar datos',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => MemberFormScreen(existing: m)));
                ref.invalidate(memberDetailProvider(memberId));
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(tooltip: 'Dar de baja', icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(context, ref)),
        ],
      ),
      body: asyncMember.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: friendlyError(e, action: 'cargar el socio'),
          onRetry: () => ref.invalidate(memberDetailProvider(memberId)),
        ),
        data: (member) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
                child: member.photoUrl == null ? Text(member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 28)) : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(member.fullName, style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 6),
            Center(
              child: asyncStatus.maybeWhen(
                data: (s) => StatusChip(status: s.status, daysOverdue: s.daysOverdue),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('DNI'), trailing: Text(member.dni ?? '—')),
                  ListTile(leading: const Icon(Icons.phone_outlined), title: const Text('Teléfono'), trailing: Text(member.phone ?? '—')),
                  ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), trailing: Text(member.email ?? '—')),
                  ListTile(leading: const Icon(Icons.smartphone_outlined), title: const Text('IMEI'), trailing: Text(member.imei ?? '—')),
                  ListTile(leading: const Icon(Icons.event_outlined), title: const Text('Fecha de ingreso'), trailing: Text(_dateFmt.format(member.joinDate))),
                  if (member.notes != null && member.notes!.isNotEmpty) ListTile(leading: const Icon(Icons.notes_outlined), title: const Text('Notas'), subtitle: Text(member.notes!)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.replay),
                    label: const Text('Renovar ahora'),
                    onPressed: () async {
                      if (member.frozen) {
                        final go = await confirmAction(
                          context,
                          title: 'Socio congelado',
                          message: '${member.fullName} está congelado. Si cobrás la renovación, acordate de descongelarlo después. ¿Continuar?',
                          icon: Icons.ac_unit,
                        );
                        if (!go || !context.mounted) return;
                      }
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChargeScreen(preselectedMemberId: memberId)));
                      ref.invalidate(memberStatusDetailProvider(memberId));
                      ref.invalidate(memberPeriodsProvider(memberId));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Contactar'),
                    onPressed: () => openWhatsApp(context, member.phone, memberName: member.fullName),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: Icon(member.frozen ? Icons.ac_unit : Icons.ac_unit_outlined),
              label: Text(member.frozen ? 'Descongelar socio' : 'Congelar socio'),
              onPressed: () => _toggleFrozen(context, ref, member),
            ),
            const SizedBox(height: 20),
            Text('Historial de pagos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            asyncPeriods.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                friendlyError(e, action: 'cargar el historial'),
                style: const TextStyle(color: Colors.red),
              ),
              data: (periods) {
                if (periods.isEmpty) return const Text('Sin períodos registrados aún', style: TextStyle(color: Colors.grey));
                return Column(
                  children: periods
                      .map(
                        (p) => Card(
                          child: ListTile(
                            title: Text('${_dateFmt.format(p.startDate)} → ${_dateFmt.format(p.endDate)}'),
                            subtitle: Text('${p.daysPerWeek} días/sem${p.hasTrainer ? ' · con entrenador' : ''} · ${p.paymentMethod.label}'),
                            trailing: Text(formatGs(p.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
