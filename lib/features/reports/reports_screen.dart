import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/validators.dart';
import '../../data/models/membership_period.dart';
import '../../providers/repository_providers.dart';
import 'report_export.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  List<MembershipPeriod> _periods = [];
  List<Map<String, dynamic>> _renewalRows = [];
  List<Map<String, dynamic>> _lateRanking = [];
  bool _loading = true;
  bool _exporting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final periodRepo = ref.read(periodRepositoryProvider);
      final from = DateTime(_from.year, _from.month, _from.day);
      final toExclusive = DateTime(_to.year, _to.month, _to.day).add(const Duration(days: 1));
      final periods = await periodRepo.getByChargeDateRange(from, toExclusive);
      final renewal = await periodRepo.getRenewalStats(_from, _to);
      final ranking = await periodRepo.getLateRenewalRanking();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _renewalRows = renewal;
        _lateRanking = ranking;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = friendlyError(e, action: 'cargar el reporte');
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(context: context, initialDate: isFrom ? _from : _to, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked == null || !mounted) return;
    final newFrom = isFrom ? picked : _from;
    final newTo = isFrom ? _to : picked;
    final err = Validators.dateRange(newFrom, newTo);
    if (err != null) {
      showError(context, err);
      return;
    }
    setState(() {
      _from = newFrom;
      _to = newTo;
    });
    _load();
  }

  Future<void> _export(Future<void> Function() action) async {
    if (_periods.isEmpty) {
      showWarning(context, 'No hay cobros entre esas fechas, así que no hay nada para exportar. Cambiá el rango de fechas.');
      return;
    }
    setState(() => _exporting = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, 'No se pudo generar el archivo. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final realTotal = _periods.fold<int>(0, (a, p) => a + p.totalAmount);
    final listTotal = _periods.fold<int>(0, (a, p) => a + (p.listPrice ?? p.basePrice) + p.trainerPrice);
    final discount = listTotal - realTotal;

    final byDays = <int, int>{};
    int trainerTotal = 0, noTrainerTotal = 0;
    for (final p in _periods) {
      byDays[p.daysPerWeek] = (byDays[p.daysPerWeek] ?? 0) + p.totalAmount;
      if (p.hasTrainer) {
        trainerTotal += p.trainerPrice;
        noTrainerTotal += p.basePrice;
      } else {
        noTrainerTotal += p.basePrice;
      }
    }

    final renewedCount = _renewalRows.where((r) => r['renewed'] == true).length;
    final renewalRate = _renewalRows.isEmpty ? null : renewedCount / _renewalRows.length * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
            onPressed: (_loading || _exporting) ? null : () => _export(() => exportReportPdf(from: _from, to: _to, periods: _periods)),
          ),
          IconButton(
            icon: const Icon(Icons.grid_on_outlined),
            tooltip: 'Exportar Excel',
            onPressed: (_loading || _exporting) ? null : () => _export(() => exportReportExcel(from: _from, to: _to, periods: _periods)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? ErrorRetry(message: _loadError!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => _pickDate(isFrom: true), child: Text('Desde: ${_dateFmt.format(_from)}')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(onPressed: () => _pickDate(isFrom: false), child: Text('Hasta: ${_dateFmt.format(_to)}')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(context, Icons.compare_arrows_rounded, const Color(0xFF2563EB), 'Ingresos reales vs. de lista'),
                          const SizedBox(height: 12),
                          _kv('Real cobrado', formatGs(realTotal)),
                          _kv('Precio de lista', formatGs(listTotal)),
                          _kv('Descuentos otorgados', formatGs(discount)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(context, Icons.calendar_view_week_rounded, const Color(0xFF16A34A), 'Por modalidad de días'),
                          const SizedBox(height: 12),
                          ...byDays.entries.map((e) => _kv('${e.key} días/semana', formatGs(e.value))),
                          const Divider(),
                          _kv('Con entrenador de piso', formatGs(trainerTotal)),
                          _kv('Sin entrenador', formatGs(noTrainerTotal)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEA580C).withValues(alpha: 0.14),
                        child: const Icon(Icons.autorenew_rounded, color: Color(0xFFEA580C)),
                      ),
                      title: const Text('Tasa de renovación'),
                      subtitle: Text('$renewedCount de ${_renewalRows.length} vencimientos renovados'),
                      trailing: Text(renewalRate == null ? '—' : '${renewalRate.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(context, Icons.warning_amber_rounded, const Color(0xFFDC2626), 'Ranking de morosos recurrentes'),
                          const SizedBox(height: 8),
                          if (_lateRanking.isEmpty)
                            const Text('Sin renovaciones tardías registradas', style: TextStyle(color: Colors.grey))
                          else
                            ..._lateRanking.take(10).map((r) => _kv(r['full_name'] as String, '${r['late_renewals_count']} veces')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _sectionTitle(BuildContext context, IconData icon, Color color, String text) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Text(text, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
