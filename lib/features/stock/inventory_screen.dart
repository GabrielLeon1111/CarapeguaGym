import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feedback.dart';
import '../../data/models/stock_product.dart';
import '../../providers/repository_providers.dart';
import 'damage_sheet.dart';
import 'movements_tab.dart';
import 'product_form_sheet.dart';
import 'product_picker.dart';
import 'purchase_sheet.dart';
import 'sale_sheet.dart';
import 'stock_style.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

final stockProductsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(stockRepositoryProvider).getProducts();
});

final stockCategoriesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(stockRepositoryProvider).getCategories();
});

final stockMonthSummaryProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(stockRepositoryProvider).getMonthSummary();
});

void refreshStock(WidgetRef ref) {
  ref.invalidate(stockProductsProvider);
  ref.invalidate(stockCategoriesProvider);
  ref.invalidate(stockMonthSummaryProvider);
  ref.invalidate(stockMovementsProvider);
}

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventario y stock'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Inventario'),
              Tab(text: 'Operaciones'),
              Tab(text: 'Movimientos'),
            ],
          ),
        ),
        body: const TabBarView(children: [_InventoryTab(), _OperationsTab(), MovementsTab()]),
      ),
    );
  }
}

// ---------------- Inventario ----------------

class _InventoryTab extends ConsumerStatefulWidget {
  const _InventoryTab();

  @override
  ConsumerState<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends ConsumerState<_InventoryTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final asyncProducts = ref.watch(stockProductsProvider);
    final asyncSummary = ref.watch(stockMonthSummaryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final cats = ref.read(stockCategoriesProvider).value ?? const <String>[];
          await showProductFormSheet(context, ref, categories: cats, onSaved: () => refreshStock(ref));
        },
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshStock(ref),
        child: asyncProducts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(
            message: friendlyError(e, action: 'cargar el inventario'),
            onRetry: () => refreshStock(ref),
          ),
          data: (products) {
            final q = _search.trim().toLowerCase();
            final filtered = q.isEmpty ? products : products.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();
            final capital = products.fold<int>(0, (a, p) => a + p.investedCapital);

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _SummaryCard(capital: capital, summary: asyncSummary),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(hintText: 'Buscar por nombre o categoría', prefixIcon: Icon(Icons.search), isDense: true),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 8),
                if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Todavía no hay productos.\nTocá "Producto" para crear el primero.',
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
                  ...filtered.map((p) => _ProductCard(product: p, onChanged: () => refreshStock(ref))),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int capital;
  final AsyncValue<({int revenue, int profit, int units})> summary;
  const _SummaryCard({required this.capital, required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Capital invertido en stock', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(formatGs(capital), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            summary.when(
              loading: () => const Text('Cargando ganancias...', style: TextStyle(fontSize: 12)),
              error: (_, _) => const SizedBox.shrink(),
              data: (s) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_mini('Ventas del mes', formatGs(s.revenue)), _mini('Ganancia', formatGs(s.profit)), _mini('Vendidos', '${s.units}')],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}

class _ProductCard extends ConsumerWidget {
  final StockProduct product;
  final VoidCallback onChanged;
  const _ProductCard({required this.product, required this.onChanged});

  (Color, String) get _estado {
    if (product.isOutOfStock) return (Colors.red, 'Sin stock');
    if (product.isLowStock) return (Colors.orange, 'Stock bajo');
    return (Colors.green, 'OK');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = stockCategoryStyle(product.category);
    final (estadoColor, estadoText) = _estado;
    final expiringSoon = product.expiration != null && product.expiration!.difference(DateTime.now()).inDays <= 30;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showActions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(fontWeight: FontWeight.bold, color: product.active ? null : Colors.grey),
                        ),
                        Text('${product.category} · ${product.isService ? 'por scoop' : 'por unidad'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: estadoColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      estadoText,
                      style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _cell('Stock', '${product.stockQty}', bold: true),
                  _cell('Costo prom.', formatGs(product.avgCost)),
                  _cell('Precio', formatGs(product.salePrice)),
                  _cell('Valorizado', formatGs(product.stockValue)),
                ],
              ),
              if (product.expiration != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.event_busy_outlined, size: 14, color: expiringSoon ? Colors.red : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Vence ${_dateFmt.format(product.expiration!)}',
                      style: TextStyle(fontSize: 12, color: expiringSoon ? Colors.red : Colors.grey, fontWeight: expiringSoon ? FontWeight.bold : FontWeight.normal),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(String label, String value, {bool bold = false}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(product.name, style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: Colors.blue),
              title: const Text('Vender / cobrar'),
              onTap: () {
                Navigator.pop(context);
                showSaleSheet(context, ref, product, onSaved: onChanged);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart, color: Colors.green),
              title: const Text('Registrar compra'),
              onTap: () {
                Navigator.pop(context);
                showPurchaseSheet(context, ref, product, onSaved: onChanged);
              },
            ),
            ListTile(
              leading: Icon(Icons.remove_circle_outline, color: Colors.orange.shade800),
              title: const Text('Registrar averiado / baja'),
              onTap: () {
                Navigator.pop(context);
                showDamageSheet(context, ref, product, onSaved: onChanged);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar producto'),
              onTap: () {
                Navigator.pop(context);
                final cats = ref.read(stockCategoriesProvider).value ?? const <String>[];
                showProductFormSheet(context, ref, existing: product, categories: cats, onSaved: onChanged);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Operaciones ----------------

class _OperationsTab extends ConsumerWidget {
  const _OperationsTab();

  Future<void> _run(BuildContext context, WidgetRef ref, {required bool onlyWithStock, required String title, required void Function(StockProduct) open}) async {
    final products = ref.read(stockProductsProvider).value ?? const <StockProduct>[];
    if (products.isEmpty) {
      showWarning(context, 'Primero creá un producto en la pestaña Inventario.');
      return;
    }
    final picked = await pickProduct(context, products: products, title: title, onlyWithStock: onlyWithStock);
    if (picked != null && context.mounted) open(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text('Elegí qué operación querés hacer:', style: TextStyle(color: Colors.grey)),
        ),
        _opCard(
          context,
          icon: Icons.point_of_sale,
          color: Colors.blue,
          title: 'Vender / cobrar producto',
          subtitle: 'Registra la salida por venta y la cobra.',
          onTap: () => _run(
            context,
            ref,
            onlyWithStock: true,
            title: 'Vender: elegí el producto',
            open: (p) => showSaleSheet(context, ref, p, onSaved: () => refreshStock(ref)),
          ),
        ),
        _opCard(
          context,
          icon: Icons.add_shopping_cart,
          color: Colors.green,
          title: 'Registrar compra',
          subtitle: 'Ingresa mercadería con costo y vencimiento. Recalcula el costo promedio.',
          onTap: () => _run(
            context,
            ref,
            onlyWithStock: false,
            title: 'Comprar: elegí el producto',
            open: (p) => showPurchaseSheet(context, ref, p, onSaved: () => refreshStock(ref)),
          ),
        ),
        _opCard(
          context,
          icon: Icons.remove_circle_outline,
          color: Colors.orange.shade800,
          title: 'Registrar averiado / baja',
          subtitle: 'Da de baja productos dañados o vencidos.',
          onTap: () => _run(
            context,
            ref,
            onlyWithStock: true,
            title: 'Baja: elegí el producto',
            open: (p) => showDamageSheet(context, ref, p, onSaved: () => refreshStock(ref)),
          ),
        ),
      ],
    );
  }

  Widget _opCard(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
