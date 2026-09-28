import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feedback.dart';
import '../../data/models/payment_method.dart';
import '../../providers/repository_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');
final _dayNameFmt = DateFormat("EEEE d 'de' MMMM", 'es');
final _timeFmt = DateFormat('HH:mm');

/// Una línea de la caja: puede ser una cuota de socio o un pase del día.
class _CashEntry {
  final int amount;
  final PaymentMethod method;
  final DateTime date;
  final String label;
  final bool hasTrainer;
  const _CashEntry({required this.amount, required this.method, required this.date, required this.label, this.hasTrainer = false});
}

/// "Caja del día": muestra lo cobrado en un día. Por defecto hoy, y arranca de
/// cero cada día solo. No hay que abrir ni cerrar nada; las flechas sirven para
/// mirar días anteriores.
class CashClosingTab extends ConsumerStatefulWidget {
  const CashClosingTab({super.key});

  @override
  ConsumerState<CashClosingTab> createState() => _CashClosingTabState();
}

class _CashClosingTabState extends ConsumerState<CashClosingTab> {
  DateTime _day = DateTime.now();
  PaymentMethod? _methodFilter;
  late Future<List<_CashEntry>> _future = _fetch();

  DateTime get _dayStart => DateTime(_day.year, _day.month, _day.day);
  DateTime get _dayEnd => _dayStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  Future<List<_CashEntry>> _fetch() async {
    final periods = await ref.read(periodRepositoryProvider).getByChargeDateRange(_dayStart, _dayEnd, paymentMethod: _methodFilter?.name);
    final passes = await ref.read(dailyPassRepositoryProvider).getByDateRange(_dayStart, _dayEnd);
    final entries = <_CashEntry>[
      for (final p in periods) _CashEntry(amount: p.totalAmount, method: p.paymentMethod, date: p.createdAt, label: 'Cuota de socio', hasTrainer: p.hasTrainer),
      for (final p in passes)
        if (_methodFilter == null || p.paymentMethod == _methodFilter) _CashEntry(amount: p.amount, method: p.paymentMethod, date: p.createdAt, label: 'Pase del día'),
    ];
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  void _reload() => setState(() => _future = _fetch());

  void _changeDay(int deltaDays) {
    final next = _dayStart.add(Duration(days: deltaDays));
    // No se puede ir más allá de hoy (no hay cobros en el futuro).
    if (next.isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) return;
    _day = next;
    _reload();
  }

  void _goToday() {
    if (_isToday) return;
    _day = DateTime.now();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            children: [
              // Selector de día con flechas. Sin "abrir/cerrar": solo navegar.
              Row(
                children: [
                  IconButton(tooltip: 'Día anterior', icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(-1)),
                  Expanded(
                    child: Column(
                      children: [
                        Text(_isToday ? 'Hoy' : _capitalize(_dayNameFmt.format(_day)), style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                        Text(_dateFmt.format(_day), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Día siguiente', icon: const Icon(Icons.chevron_right), onPressed: _isToday ? null : () => _changeDay(1)),
                ],
              ),
              if (!_isToday)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(onPressed: _goToday, icon: const Icon(Icons.today, size: 18), label: const Text('Volver a hoy')),
                ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButtonFormField<PaymentMethod?>(
                  initialValue: _methodFilter,
                  decoration: const InputDecoration(labelText: 'Método de pago', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.label))),
                  ],
                  onChanged: (m) {
                    _methodFilter = m;
                    _reload();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorRetry(
                  message: friendlyError(snapshot.error!, action: 'cargar la caja del día'),
                  onRetry: _reload,
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final entries = snapshot.data!;
              final total = entries.fold<int>(0, (a, e) => a + e.amount);
              return Column(
                children: [
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_isToday ? 'Total cobrado hoy' : 'Total del día', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${entries.length} ${entries.length == 1 ? 'cobro' : 'cobros'}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                          Text(formatGs(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        ],
                      ),
                    ),
                  ),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_isToday ? 'Todavía no cobraste nada hoy.' : 'No hubo cobros este día.', style: const TextStyle(color: Colors.grey)),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        return ListTile(
                          title: Text(formatGs(e.amount)),
                          subtitle: Text('${e.label} · ${e.method.label} · ${_timeFmt.format(e.date)}'),
                          trailing: e.hasTrainer ? const Icon(Icons.fitness_center, size: 18) : null,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
