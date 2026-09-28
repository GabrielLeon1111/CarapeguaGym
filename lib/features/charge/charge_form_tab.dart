import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/thousands_input_formatter.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/validators.dart';
import '../../data/models/member.dart';
import '../../data/models/membership_period.dart';
import '../../data/models/payment_method.dart';
import '../../data/models/plan.dart';
import '../../providers/repository_providers.dart';
import '../members/member_form_screen.dart';
import '../notifications/notification_service.dart';
import 'charge_validation.dart';
import 'receipt_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

final activePlansProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(planRepositoryProvider).getAll(activeOnly: true);
});

class ChargeFormTab extends ConsumerStatefulWidget {
  final String? preselectedMemberId;

  /// Cuando se entra desde el panel de Membresías con un paquete ya elegido.
  final Plan? preselectedPlan;

  const ChargeFormTab({super.key, this.preselectedMemberId, this.preselectedPlan});

  @override
  ConsumerState<ChargeFormTab> createState() => _ChargeFormTabState();
}

class _ChargeFormTabState extends ConsumerState<ChargeFormTab> {
  final _searchCtrl = TextEditingController();
  final _basePriceCtrl = TextEditingController();
  final _trainerPriceCtrl = TextEditingController();
  Timer? _debounce;

  Member? _member;
  List<Member> _searchResults = [];
  String _lastSearchTerm = '';
  bool _searching = false;
  String? _searchError;
  MembershipPeriod? _previousPeriod;
  bool _loadingMember = false;

  Plan? _selectedPlan;
  int _daysPerWeek = 7;
  bool _hasTrainer = false;
  PaymentMethod _paymentMethod = PaymentMethod.efectivo;
  DateTime _startDate = dateOnly(DateTime.now());
  final _monthsCtrl = TextEditingController(text: '1');
  bool _saving = false;
  String? _formError;

  bool get _planLocked => widget.preselectedPlan != null;
  bool get _returnAfterCharge => widget.preselectedMemberId != null || widget.preselectedPlan != null;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPlan != null) {
      _applyPlan(widget.preselectedPlan!, notify: false);
    }
    if (widget.preselectedMemberId != null) {
      _loadPreselected(widget.preselectedMemberId!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _basePriceCtrl.dispose();
    _trainerPriceCtrl.dispose();
    _monthsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreselected(String id) async {
    setState(() => _loadingMember = true);
    try {
      final member = await ref.read(memberRepositoryProvider).getById(id);
      final prev = await ref.read(periodRepositoryProvider).getLatestForMember(id);
      if (!mounted) return;
      setState(() {
        _member = member;
        _searchCtrl.text = member.fullName;
        _applyPrevious(prev);
      });
    } catch (e) {
      if (mounted) setState(() => _formError = friendlyError(e, action: 'cargar el socio'));
    } finally {
      if (mounted) setState(() => _loadingMember = false);
    }
  }

  /// Precarga datos del último período y sugiere la fecha de inicio correcta.
  /// El paquete no se toca acá: eso lo define el plan elegido.
  void _applyPrevious(MembershipPeriod? prev) {
    _previousPeriod = prev;
    _startDate = suggestedStartDate(prev?.endDate, DateTime.now());
    if (prev != null && !_planLocked) {
      _hasTrainer = prev.hasTrainer;
      // El período anterior guarda el costo del entrenador por el período entero;
      // se divide por sus meses para volver a mostrar el costo mensual.
      final prevMonths = (prev.endDate.year - prev.startDate.year) * 12 + (prev.endDate.month - prev.startDate.month);
      final monthlyTrainer = prev.trainerPrice > 0 ? (prev.trainerPrice ~/ (prevMonths < 1 ? 1 : prevMonths)) : 0;
      _trainerPriceCtrl.text = monthlyTrainer > 0 ? thousandsFormat.format(monthlyTrainer) : '';
      _paymentMethod = prev.paymentMethod;
    }
  }

  void _onSearchChanged(String term) {
    if (_member != null && term != _member!.fullName) {
      setState(() {
        _member = null;
        _previousPeriod = null;
      });
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(term));
  }

  Future<void> _search(String term) async {
    _lastSearchTerm = term.trim();
    if (_lastSearchTerm.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await ref.read(memberRepositoryProvider).search(_lastSearchTerm);
      if (!mounted || _lastSearchTerm != term.trim()) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = friendlyError(e, action: 'buscar');
      });
    }
  }

  Future<void> _selectMember(Member m) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _member = m;
      _searchResults = [];
      _searchCtrl.text = m.fullName;
      _loadingMember = true;
      _formError = null;
    });
    try {
      final prev = await ref.read(periodRepositoryProvider).getLatestForMember(m.id);
      if (!mounted || _member?.id != m.id) return;
      setState(() => _applyPrevious(prev));
      if (m.frozen) showWarning(context, '${m.fullName} está congelado.');
    } catch (e) {
      if (mounted) showWarning(context, 'No se pudo cargar el último pago del socio. Revisá bien las fechas antes de cobrar.');
    } finally {
      if (mounted) setState(() => _loadingMember = false);
    }
  }

  Future<void> _createMemberInline() async {
    final created = await Navigator.push<Member>(context, MaterialPageRoute(builder: (_) => MemberFormScreen(prefilledName: _lastSearchTerm)));
    if (created != null && mounted) {
      await _selectMember(created);
    }
  }

  void _applyPlan(Plan plan, {bool notify = true}) {
    _selectedPlan = plan;
    _daysPerWeek = plan.daysPerWeek;
    _basePriceCtrl.text = thousandsFormat.format(plan.price);
    _formError = null;
    if (notify) setState(() {});
  }

  // Precios MENSUALES (por mes). El total multiplica por la cantidad de meses.
  int get _monthlyBase => ThousandsInputFormatter.parse(_basePriceCtrl.text);
  int get _monthlyTrainer => _hasTrainer ? ThousandsInputFormatter.parse(_trainerPriceCtrl.text) : 0;
  int get _months => int.tryParse(_monthsCtrl.text.trim()) ?? 0;
  int get _monthsSafe => _months < 1 ? 1 : _months;
  int get _total => (_monthlyBase + _monthlyTrainer) * _monthsSafe;
  DateTime get _endDate => addMonths(_startDate, _monthsSafe);

  Future<bool> _confirmCharge(List<String> warnings) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cobro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Socio: ${_member!.fullName}'),
              Text('Paquete: ${_selectedPlan?.name ?? '—'} ($_daysPerWeek días/semana)${_hasTrainer ? ' + entrenador' : ''}'),
              Text('Duración: $_monthsSafe ${_monthsSafe == 1 ? 'mes' : 'meses'}'),
              Text('Pago: ${_paymentMethod.label}'),
              Text('Período: ${_dateFmt.format(_startDate)} → ${_dateFmt.format(_endDate)}'),
              const SizedBox(height: 8),
              Text('Total: ${formatGs(_total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(w, style: TextStyle(color: Colors.orange.shade900)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Revisar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Cobrar ${formatGs(_total)}')),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _charge() async {
    FocusScope.of(context).unfocus();
    if (_months < 1 || _months > 12) {
      setState(() => _formError = 'La duración debe ser entre 1 y 12 meses.');
      showError(context, 'La duración debe ser entre 1 y 12 meses.');
      return;
    }
    final check = checkCharge(
      memberSelected: _member != null,
      searchText: _searchCtrl.text,
      memberFrozen: _member?.frozen ?? false,
      catalogMode: true,
      planSelected: _selectedPlan != null,
      listPrice: _selectedPlan?.price,
      basePrice: _monthlyBase,
      hasTrainer: _hasTrainer,
      trainerPrice: ThousandsInputFormatter.parse(_trainerPriceCtrl.text),
      startDate: _startDate,
      previousEndDate: _previousPeriod?.endDate,
      today: DateTime.now(),
    );
    if (!check.ok) {
      setState(() => _formError = check.errors.join('\n\n'));
      showError(context, check.errors.first);
      return;
    }
    setState(() => _formError = null);
    if (!await _confirmCharge(check.warnings) || !mounted) return;

    setState(() => _saving = true);
    MembershipPeriod created;
    try {
      final draft = MembershipPeriod(
        id: '',
        memberId: _member!.id,
        planId: _selectedPlan?.id,
        daysPerWeek: _daysPerWeek,
        basePrice: _monthlyBase * _monthsSafe,
        listPrice: _selectedPlan != null ? _selectedPlan!.price * _monthsSafe : null,
        hasTrainer: _hasTrainer,
        trainerPrice: _monthlyTrainer * _monthsSafe,
        totalAmount: _total,
        paymentMethod: _paymentMethod,
        startDate: _startDate,
        endDate: _endDate,
        createdAt: DateTime.now(),
      );
      created = await ref.read(periodRepositoryProvider).create(draft);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = '${friendlyError(e, action: 'registrar el cobro')}\nEl cobro NO se guardó.';
        });
      }
      return;
    }

    // El cobro ya está guardado: un fallo acá no debe hacer pensar que no se cobró.
    try {
      await NotificationService.instance.rescheduleAll(ref.read(memberRepositoryProvider), ref.read(settingsRepositoryProvider));
    } catch (_) {}

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => ReceiptDialog(period: created, memberName: _member!.fullName),
    );
    if (!mounted) return;
    if (_returnAfterCharge) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _saving = false;
      _member = null;
      _searchCtrl.clear();
      _searchResults = [];
      _lastSearchTerm = '';
      _previousPeriod = null;
      _selectedPlan = null;
      _basePriceCtrl.clear();
      _trainerPriceCtrl.clear();
      _hasTrainer = false;
      _daysPerWeek = 7;
      _startDate = dateOnly(DateTime.now());
      _monthsCtrl.text = '1';
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncPlans = ref.watch(activePlansProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('1. Socio', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('charge_search'),
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o DNI',
            prefixIcon: Icon(_member != null ? Icons.check_circle : Icons.search, color: _member != null ? Colors.green : null),
            suffixIcon: _searching || _loadingMember
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (_searchCtrl.text.isNotEmpty && widget.preselectedMemberId == null)
                ? IconButton(
                    tooltip: 'Borrar',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            helperText: _member != null ? 'Socio seleccionado ✓' : null,
            helperStyle: const TextStyle(color: Colors.green),
          ),
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          onChanged: _onSearchChanged,
          enabled: widget.preselectedMemberId == null && !_saving,
        ),
        if (_searchError != null) InlineError(_searchError),
        if (_searchResults.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: Column(
              children: _searchResults
                  .map(
                    (m) => ListTile(
                      leading: CircleAvatar(backgroundColor: scheme.primaryContainer, child: Text(m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : '?')),
                      title: Text(m.fullName),
                      subtitle: Text([m.dni, if (m.frozen) 'Congelado'].whereType<String>().join(' · ')),
                      onTap: () => _selectMember(m),
                    ),
                  )
                  .toList(),
            ),
          )
        else if (!_searching && _searchError == null && _lastSearchTerm.isNotEmpty && _member == null)
          Card(
            margin: const EdgeInsets.only(top: 8),
            color: scheme.secondaryContainer.withValues(alpha: 0.5),
            child: ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: Text('No se encontró "$_lastSearchTerm"'),
              subtitle: const Text('Revisá cómo lo escribiste, o tocá acá para registrarlo como socio nuevo'),
              onTap: _createMemberInline,
            ),
          ),
        if (_previousPeriod != null) ...[
          const SizedBox(height: 8),
          Card(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Período anterior: ${_previousPeriod!.daysPerWeek} días/sem'
                '${_previousPeriod!.hasTrainer ? ' + entrenador' : ''} · ${formatGs(_previousPeriod!.totalAmount)}'
                ' · ${_previousPeriod!.endDate.isBefore(dateOnly(DateTime.now())) ? 'venció' : 'vence'} ${_dateFmt.format(_previousPeriod!.endDate)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('2. Paquete', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_planLocked)
          Card(
            color: scheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.card_membership),
              title: Text(widget.preselectedPlan!.name),
              subtitle: Text('${widget.preselectedPlan!.daysPerWeek} días/semana · ${formatGs(widget.preselectedPlan!.price)}'),
            ),
          )
        else
          asyncPlans.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => InlineError(friendlyError(e, action: 'cargar los paquetes')),
            data: (plans) => plans.isEmpty
                ? const InlineError('No hay paquetes activos. Crealos en Más → Catálogo de planes.')
                : DropdownButtonFormField<Plan>(
                    key: const Key('charge_plan'),
                    initialValue: plans.any((p) => p.id == _selectedPlan?.id) ? plans.firstWhere((p) => p.id == _selectedPlan?.id) : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Paquete', hintText: 'Tocá para elegir un paquete'),
                    items: plans
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} (${p.daysPerWeek} días - ${formatGs(p.price)})', overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (p) => p != null ? _applyPlan(p) : null,
                  ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('days_$_daysPerWeek'),
                initialValue: _daysPerWeek,
                decoration: const InputDecoration(labelText: 'Días por semana', helperText: 'Lo define el paquete'),
                items: List.generate(7, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                onChanged: null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('charge_price'),
                controller: _basePriceCtrl,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Precio del paquete', prefixText: 'Gs. ', helperText: 'Fijo, lo define el paquete'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('¿Contrata entrenador de piso?'), value: _hasTrainer, onChanged: (v) => setState(() => _hasTrainer = v)),
        if (_hasTrainer)
          TextField(
            key: const Key('charge_trainer_price'),
            controller: _trainerPriceCtrl,
            decoration: const InputDecoration(labelText: 'Costo entrenador', prefixText: 'Gs. '),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 20),
        Text('3. Pago y período', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<PaymentMethod>(
          key: ValueKey('pm_${_paymentMethod.name}'),
          initialValue: _paymentMethod,
          decoration: const InputDecoration(labelText: 'Método de pago'),
          items: PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.label))).toList(),
          onChanged: (m) => setState(() => _paymentMethod = m ?? _paymentMethod),
        ),
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inicio'),
                subtitle: Text(_dateFmt.format(_startDate)),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: () async {
                  final today = dateOnly(DateTime.now());
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(today.year - 1, today.month, today.day),
                    lastDate: DateTime(today.year + 1, today.month, today.day),
                    helpText: 'Día en que empieza el nuevo período',
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
            ),
            Expanded(
              child: TextField(
                key: const Key('charge_months'),
                controller: _monthsCtrl,
                decoration: const InputDecoration(labelText: 'Duración (meses)', helperText: 'De 1 a 12'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        Text('Vence: ${_dateFmt.format(_endDate)}', style: const TextStyle(color: Colors.grey)),
        InlineError(_formError),
        const SizedBox(height: 20),
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total a cobrar', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (_monthsSafe > 1) Text('${formatGs(_monthlyBase + _monthlyTrainer)} × $_monthsSafe meses', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatGs(_total), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('charge_submit'),
          onPressed: (_saving || _loadingMember) ? null : _charge,
          child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Cobrar'),
        ),
      ],
    );
  }
}
