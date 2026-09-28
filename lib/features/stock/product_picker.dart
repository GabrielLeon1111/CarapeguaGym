import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/stock_product.dart';
import 'stock_style.dart';

/// Muestra una lista con buscador para elegir un producto. Devuelve el elegido
/// o null si se cancela.
Future<StockProduct?> pickProduct(BuildContext context, {required List<StockProduct> products, String title = 'Elegí el producto', bool onlyWithStock = false}) {
  return showModalBottomSheet<StockProduct>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProductPicker(products: products, title: title, onlyWithStock: onlyWithStock),
  );
}

class _ProductPicker extends StatefulWidget {
  final List<StockProduct> products;
  final String title;
  final bool onlyWithStock;
  const _ProductPicker({required this.products, required this.title, required this.onlyWithStock});

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final base = widget.onlyWithStock ? widget.products.where((p) => p.stockQty > 0).toList() : widget.products;
    final q = _search.trim().toLowerCase();
    final filtered = q.isEmpty ? base : base.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Buscar producto', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay productos.', style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final p = filtered[i];
                  final (icon, color) = stockCategoryStyle(p.category);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.14),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.stockQty} ${p.unitLabel} · ${formatGs(p.salePrice)}'),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
