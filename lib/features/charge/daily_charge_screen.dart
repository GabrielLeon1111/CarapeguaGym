import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feedback.dart';
import '../stock/inventory_screen.dart';
import '../stock/sale_sheet.dart';
import '../stock/stock_style.dart';
import 'daily_pass_tab.dart';

/// Pantalla del día a día en la recepción: cobrar el pase del día y vender
/// productos (scoops, bebidas, etc.), todo desde un solo lugar.
class DailyChargeScreen extends StatelessWidget {
  const DailyChargeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cobro por día'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pase del día'),
              Tab(text: 'Vender producto'),
            ],
          ),
        ),
        body: const TabBarView(children: [DailyPassTab(), _QuickSellTab()]),
      ),
    );
  }
}

class _QuickSellTab extends ConsumerStatefulWidget {
  const _QuickSellTab();

  @override
  ConsumerState<_QuickSellTab> createState() => _QuickSellTabState();
}

class _QuickSellTabState extends ConsumerState<_QuickSellTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stockProductsProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshStock(ref),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: friendlyError(e, action: 'cargar los productos'),
          onRetry: () => refreshStock(ref),
        ),
        data: (products) {
          final active = products.where((p) => p.active).toList();
          final q = _search.trim().toLowerCase();
          final filtered = q.isEmpty ? active : active.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              TextField(
                decoration: const InputDecoration(hintText: 'Buscar producto', prefixIcon: Icon(Icons.search), isDense: true),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No hay productos cargados.\nCrealos en Más → Inventario.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No hay productos que coincidan con "$_search".', textAlign: TextAlign.center)),
                )
              else
                ...filtered.map((p) {
                  final (icon, color) = stockCategoryStyle(p.category);
                  final out = p.isOutOfStock;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.14),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(p.name),
                      subtitle: Text(out ? 'Sin stock' : '${p.stockQty} ${p.unitLabel} · ${formatGs(p.salePrice)}', style: TextStyle(color: out ? Colors.red : null)),
                      trailing: FilledButton.icon(
                        onPressed: out
                            ? null
                            : () async {
                                await showSaleSheet(context, ref, p, onSaved: () => refreshStock(ref));
                              },
                        icon: const Icon(Icons.point_of_sale, size: 18),
                        label: const Text('Vender'),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
