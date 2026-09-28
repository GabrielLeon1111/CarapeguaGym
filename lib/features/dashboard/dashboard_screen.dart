import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feedback.dart';
import '../../data/models/membership_period.dart';
import '../../data/repositories/stock_repository.dart';
import '../../providers/repository_providers.dart';
import 'dashboard_data.dart';

final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - 11, 1);
  final periodRepository = ref.watch(periodRepositoryProvider);
  final stockRepository = ref.watch(stockRepositoryProvider);
  final results = await Future.wait([
    periodRepository.getByChargeDateRange(from, now.add(const Duration(days: 1))),
    stockRepository.getSalesSummary(DateTime(now.year, now.month, 1), now.add(const Duration(days: 1))),
  ]);
  return DashboardData.compute(results[0] as List<MembershipPeriod>, now, productSales: results[1] as List<StockSalesSummary>);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(dashboardDataProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganancias'),
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipOval(child: Image.asset('assets/images/logo.jpeg', fit: BoxFit.cover)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardDataProvider),
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(
            message: friendlyError(e, action: 'cargar las ganancias'),
            onRetry: () => ref.invalidate(dashboardDataProvider),
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryGrid(data: data),
              const SizedBox(height: 16),
              _MonthComparisonCard(data: data),
              const SizedBox(height: 16),
              _BreakdownCard(data: data),
              const SizedBox(height: 16),
              _ProductSalesCard(data: data),
              const SizedBox(height: 16),
              _DiscountCard(data: data),
              const SizedBox(height: 16),
              _TrendCard(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductSalesCard extends StatelessWidget {
  final DashboardData data;
  const _ProductSalesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final revenue = data.productSales.fold<int>(0, (sum, sale) => sum + sale.revenue);
    final cost = data.productSales.fold<int>(0, (sum, sale) => sum + sale.cost);
    final profit = revenue - cost;
    final units = data.productSales.fold<int>(0, (sum, sale) => sum + sale.units);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ventas de productos este mes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_productMetric('Cobrado', revenue), _productMetric('Costo', cost), _productMetric('Ganancia', profit, emphasize: true)]),
            const SizedBox(height: 8),
            Text('$units unidades/servicios vendidos', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (data.productSales.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Más rentables', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...data.productSales
                  .take(5)
                  .map(
                    (sale) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(sale.productName, overflow: TextOverflow.ellipsis)),
                          Text(formatGs(sale.profit), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Todavía no hay ventas de productos este mes.', style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _productMetric(String label, int value, {bool emphasize = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 2),
      Text(
        formatGs(value),
        style: TextStyle(fontWeight: FontWeight.bold, color: emphasize ? const Color(0xFF16A34A) : null),
      ),
    ],
  );
}

class _SummaryGrid extends StatelessWidget {
  final DashboardData data;
  const _SummaryGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Hoy', data.todayTotal, Icons.today_rounded, const Color(0xFF16A34A)),
      ('Esta semana', data.weekTotal, Icons.date_range_rounded, const Color(0xFF2563EB)),
      ('Este mes', data.monthTotal, Icons.calendar_month_rounded, const Color(0xFF9333EA)),
      ('Este año', data.yearTotal, Icons.auto_graph_rounded, const Color(0xFFEA580C)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: items.map((i) => _StatCard(label: i.$1, value: i.$2, icon: i.$3, color: i.$4)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 2),
            Text(
              formatGs(value),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthComparisonCard extends StatelessWidget {
  final DashboardData data;
  const _MonthComparisonCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = data.monthChangePct;
    final positive = (pct ?? 0) >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mes actual vs. anterior'),
                  const SizedBox(height: 4),
                  Text('${formatGs(data.monthTotal)}  vs  ${formatGs(data.previousMonthTotal)}', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            if (pct != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: (positive ? Colors.green : Colors.red).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(positive ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: positive ? Colors.green : Colors.red),
                    Text(
                      '${pct.abs().toStringAsFixed(1)}%',
                      style: TextStyle(color: positive ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              const Text('—', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final DashboardData data;
  const _BreakdownCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Desglose del mes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _row('Planes de catálogo', data.catalogTotal),
            _row('Personalizados', data.customTotal),
            const Divider(),
            _row('Entrenador de piso', data.trainerTotal),
            _row('Cuotas (sin entrenador)', data.nonTrainerTotal),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(formatGs(value))]),
  );
}

class _DiscountCard extends StatelessWidget {
  final DashboardData data;
  const _DiscountCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEA580C).withValues(alpha: 0.14),
          child: const Icon(Icons.local_offer_outlined, color: Color(0xFFEA580C)),
        ),
        title: const Text('Descuentos otorgados este mes'),
        subtitle: const Text('Diferencia entre precio de lista y lo cobrado'),
        trailing: Text(formatGs(data.discountTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final DashboardData data;
  const _TrendCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxY = data.monthlySeries.map((e) => e.total).fold<int>(0, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evolución (12 meses)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY <= 0 ? 100 : maxY * 1.2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= data.monthlySeries.length) return const SizedBox.shrink();
                          final m = data.monthlySeries[i].month;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat.MMM('es').format(m), style: const TextStyle(fontSize: 10)),
                          );
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (int i = 0; i < data.monthlySeries.length; i++) FlSpot(i.toDouble(), data.monthlySeries[i].total.toDouble())],
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
