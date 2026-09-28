import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/thousands_input_formatter.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/validators.dart';
import '../../data/models/plan.dart';
import '../../providers/repository_providers.dart';
import '../charge/daily_pass_tab.dart' show dailyRateProvider;

final allPlansProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(planRepositoryProvider).getAll();
});

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allPlansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de planes')),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(context, ref, null), child: const Icon(Icons.add)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: friendlyError(e, action: 'cargar los planes'),
          onRetry: () => ref.invalidate(allPlansProvider),
        ),
        data: (plans) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const _DailyRateCard(),
              const SizedBox(height: 12),
              Text('Paquetes de membresía', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              if (plans.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Todavía no hay paquetes.\nTocá + para crear el primero.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...plans.map(
                  (p) => Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      title: Text(
                        p.name,
                        style: TextStyle(color: p.active ? null : Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${p.daysPerWeek} días/semana · ${formatGs(p.price)}'),
                      trailing: Tooltip(
                        message: p.active ? 'Activo: aparece al cobrar' : 'Inactivo: no aparece al cobrar',
                        child: Switch(
                          value: p.active,
                          onChanged: (v) async {
                            if (!v) {
                              final ok = await confirmAction(
                                context,
                                title: '¿Desactivar "${p.name}"?',
                                message: 'El plan deja de aparecer al cobrar. Los cobros ya hechos con este plan no cambian. Podés volver a activarlo cuando quieras.',
                                confirmLabel: 'Desactivar',
                              );
                              if (!ok) return;
                            }
                            try {
                              await ref.read(planRepositoryProvider).setActive(p.id, v);
                              ref.invalidate(allPlansProvider);
                            } catch (e) {
                              if (context.mounted) showError(context, friendlyError(e, action: 'cambiar el plan'));
                            }
                          },
                        ),
                      ),
                      onTap: () => _showForm(context, ref, p),
                    ),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Plan? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlanForm(existing: existing, existingPlans: ref.read(allPlansProvider).value ?? const [], onSaved: () => ref.invalidate(allPlansProvider)),
    );
  }
}

/// Tarjeta para ver/editar el precio del pase del día, reutilizable desde acá.
class _DailyRateCard extends ConsumerWidget {
  const _DailyRateCard();

  Future<void> _edit(BuildContext context, WidgetRef ref, int? current) async {
    final ctrl = TextEditingController(text: current != null ? thousandsFormat.format(current) : '');
    final newRate = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Precio del pase del día'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Precio por día', prefixText: 'Gs. '),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ThousandsInputFormatter.parse(ctrl.text)), child: const Text('Guardar')),
        ],
      ),
    );
    if (newRate == null) return;
    final err = Validators.amount(newRate, field: 'el precio del pase del día');
    if (err != null) {
      if (context.mounted) showError(context, err);
      return;
    }
    await ref.read(dailyRateStoreProvider).set(newRate);
    ref.invalidate(dailyRateProvider);
    if (context.mounted) showSuccess(context, 'Precio del pase del día guardado: ${formatGs(newRate)}.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailyRateProvider);
    final rate = async.value;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.today_rounded),
        title: const Text('Precio del pase del día', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(rate == null ? 'Sin configurar — tocá para cargarlo' : '${formatGs(rate)} · se reutiliza en "Cobro por día"'),
        trailing: TextButton.icon(onPressed: () => _edit(context, ref, rate), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(rate == null ? 'Configurar' : 'Cambiar')),
        onTap: () => _edit(context, ref, rate),
      ),
    );
  }
}

class _PlanForm extends ConsumerStatefulWidget {
  final Plan? existing;
  final List<Plan> existingPlans;
  final VoidCallback onSaved;
  const _PlanForm({this.existing, required this.existingPlans, required this.onSaved});

  @override
  ConsumerState<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<_PlanForm> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _priceCtrl = TextEditingController(text: widget.existing != null ? thousandsFormat.format(widget.existing!.price) : '');
  late int _days = widget.existing?.daysPerWeek ?? 7;
  bool _saving = false;

  String? _error;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final price = ThousandsInputFormatter.parse(_priceCtrl.text);
    final error = Validators.requiredText(name, message: 'Escribí un nombre para el plan (ej: "Mensual 3 días").', maxLength: 60) ?? Validators.amount(price, field: 'el precio de lista');
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final duplicate = widget.existingPlans.any((p) => p.id != widget.existing?.id && p.name.trim().toLowerCase() == name.toLowerCase());
    if (duplicate) {
      setState(() => _error = 'Ya existe un plan llamado "$name". Usá otro nombre o editá el existente.');
      return;
    }
    if (price < Validators.suspiciouslyLowAmount) {
      final ok = await confirmAction(
        context,
        title: '¿Precio correcto?',
        message: 'El precio ${formatGs(price)} es muy bajo. ¿Te faltaron ceros?',
        confirmLabel: 'Sí, es correcto',
        cancelLabel: 'Corregir',
        icon: Icons.warning_amber_rounded,
      );
      if (!ok) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(planRepositoryProvider);
    final plan = Plan(id: widget.existing?.id ?? '', name: name, daysPerWeek: _days, price: price, active: widget.existing?.active ?? true);
    try {
      if (widget.existing != null) {
        await repo.update(plan);
      } else {
        await repo.create(plan);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'guardar el plan'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing != null ? 'Editar plan' : 'Nuevo plan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            decoration: const InputDecoration(labelText: 'Nombre (ej: Mensual completo)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _days,
            decoration: const InputDecoration(labelText: 'Días por semana'),
            items: List.generate(7, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
            onChanged: (d) => setState(() => _days = d ?? _days),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(labelText: 'Precio de lista', prefixText: 'Gs. '),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
          ),
          InlineError(_error),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
