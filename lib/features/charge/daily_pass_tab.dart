import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/thousands_input_formatter.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/validators.dart';
import '../../data/models/daily_pass.dart';
import '../../data/models/payment_method.dart';
import '../../providers/repository_providers.dart';
import '../shared/client_picker.dart';

final _timeFmt = DateFormat('HH:mm');

/// Precio del pase del día guardado (o null si todavía no se configuró).
final dailyRateProvider = FutureProvider.autoDispose<int?>((ref) {
  return ref.watch(dailyRateStoreProvider).get();
});

/// Pases cobrados hoy (para el resumen del pie).
final todayPassesProvider = FutureProvider.autoDispose<List<DailyPass>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));
  return ref.watch(dailyPassRepositoryProvider).getByDateRange(start, end);
});

class DailyPassTab extends ConsumerWidget {
  const DailyPassTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRate = ref.watch(dailyRateProvider);
    return asyncRate.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetry(
        message: friendlyError(e, action: 'cargar el precio del día'),
        onRetry: () => ref.invalidate(dailyRateProvider),
      ),
      data: (rate) => rate == null ? _SetupRate() : _ChargeDaily(rate: rate),
    );
  }
}

/// Pantalla inicial: todavía no hay precio del día cargado.
class _SetupRate extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SetupRate> createState() => _SetupRateState();
}

class _SetupRateState extends ConsumerState<_SetupRate> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final amount = ThousandsInputFormatter.parse(_ctrl.text);
    final error = Validators.amount(amount, field: 'el precio del pase del día');
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dailyRateStoreProvider).set(amount);
      ref.invalidate(dailyRateProvider);
      if (mounted) showSuccess(context, 'Precio del día guardado: ${formatGs(amount)}.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar el precio. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.today_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('Configurá el precio del pase del día', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Cargá una vez cuánto cobrás por un día suelto. Después vas a poder cobrarlo con un solo toque. Podés cambiarlo cuando quieras.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('daily_setup_rate'),
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Precio por día', prefixText: 'Gs. ', hintText: 'Ej: 20.000'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
          onSubmitted: (_) => _save(),
        ),
        InlineError(_error),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('daily_setup_save'),
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar precio'),
        ),
      ],
    );
  }
}

/// Pantalla principal de cobro rápido del pase del día.
class _ChargeDaily extends ConsumerStatefulWidget {
  final int rate;
  const _ChargeDaily({required this.rate});

  @override
  ConsumerState<_ChargeDaily> createState() => _ChargeDailyState();
}

class _ChargeDailyState extends ConsumerState<_ChargeDaily> {
  PaymentMethod _paymentMethod = PaymentMethod.efectivo;
  ClientRef _client = const ClientRef();
  int _clientKey = 0; // para reiniciar el ClientPicker después de cobrar
  bool _saving = false;
  String? _error;

  Future<void> _charge() async {
    FocusScope.of(context).unfocus();
    final phoneError = Validators.phone(_client.phone);
    if (phoneError != null) {
      setState(() => _error = phoneError);
      return;
    }
    setState(() => _error = null);

    final who = _client.name;
    final confirmed = await confirmAction(
      context,
      title: 'Confirmar pase del día',
      message: 'Cobrar ${formatGs(widget.rate)} en ${_paymentMethod.label}${who == null ? ' (sin datos de cliente)' : ' a $who'}.',
      confirmLabel: 'Cobrar ${formatGs(widget.rate)}',
      icon: Icons.today_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(dailyPassRepositoryProvider)
          .create(DailyPass(id: '', firstName: _client.name, phone: _client.phone, memberId: _client.memberId, amount: widget.rate, paymentMethod: _paymentMethod, createdAt: DateTime.now()));
      ref.invalidate(todayPassesProvider);
      if (!mounted) return;
      showSuccess(context, 'Pase del día cobrado: ${formatGs(widget.rate)}.');
      setState(() {
        _client = const ClientRef();
        _clientKey++;
        _paymentMethod = PaymentMethod.efectivo;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'cobrar el pase del día'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const Icon(Icons.today_rounded),
            title: const Text('Precio del pase del día', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${formatGs(widget.rate)} · se cambia en Catálogo de planes'),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PaymentMethod>(
          key: ValueKey('daily_pm_${_paymentMethod.name}'),
          initialValue: _paymentMethod,
          decoration: const InputDecoration(labelText: 'Método de pago'),
          items: PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.label))).toList(),
          onChanged: (m) => setState(() => _paymentMethod = m ?? _paymentMethod),
        ),
        const SizedBox(height: 8),
        ClientPicker(key: ValueKey('daily_client_$_clientKey'), onChanged: (c) => _client = c),
        InlineError(_error),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('daily_charge'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _saving ? null : _charge,
          icon: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.point_of_sale),
          label: Text(_saving ? 'Cobrando...' : 'Cobrar pase del día — ${formatGs(widget.rate)}', style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 20),
        const _TodaySummary(),
      ],
    );
  }
}

/// Resumen de los pases cobrados hoy, con opción de anular o asociar socio.
class _TodaySummary extends ConsumerWidget {
  const _TodaySummary();

  Future<void> _void(BuildContext context, WidgetRef ref, DailyPass p) async {
    final ok = await confirmAction(
      context,
      title: '¿Anular este pase?',
      message: 'Vas a anular el pase de ${p.displayName} por ${formatGs(p.amount)}. Se revierte el cobro. ¿Seguro?',
      confirmLabel: 'Anular',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok) return;
    try {
      await ref.read(dailyPassRepositoryProvider).delete(p.id);
      ref.invalidate(todayPassesProvider);
      if (context.mounted) showSuccess(context, 'Pase anulado.');
    } catch (e) {
      if (context.mounted) showError(context, friendlyError(e, action: 'anular el pase'));
    }
  }

  Future<void> _associate(BuildContext context, WidgetRef ref, DailyPass p) async {
    final saved = await showClientAssociateSheet(context, title: 'Asociar cliente al pase');
    if (saved == null) return;
    try {
      await ref.read(dailyPassRepositoryProvider).updateClient(p.id, memberId: saved.memberId, firstName: saved.name, phone: saved.phone);
      ref.invalidate(todayPassesProvider);
      if (context.mounted) showSuccess(context, 'Cliente asociado.');
    } catch (e) {
      if (context.mounted) showError(context, friendlyError(e, action: 'asociar el cliente'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayPassesProvider);
    return async.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Text(
        friendlyError(e, action: 'cargar los pases de hoy'),
        style: const TextStyle(color: Colors.red),
      ),
      data: (passes) {
        final total = passes.fold<int>(0, (a, p) => a + p.amount);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pases de hoy (${passes.length})', style: Theme.of(context).textTheme.titleMedium),
                Text(formatGs(total), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            if (passes.isEmpty)
              const Text('Todavía no cobraste ningún pase hoy.', style: TextStyle(color: Colors.grey))
            else
              ...passes.map(
                (p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: Text(p.displayName),
                  subtitle: Text('${p.paymentMethod.label} · ${_timeFmt.format(p.createdAt)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatGs(p.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                      PopupMenuButton<String>(
                        onSelected: (v) => v == 'anular' ? _void(context, ref, p) : _associate(context, ref, p),
                        itemBuilder: (_) => [
                          if (!p.hasClient || p.memberId == null) const PopupMenuItem(value: 'asociar', child: Text('Asociar cliente')),
                          const PopupMenuItem(value: 'anular', child: Text('Anular')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
