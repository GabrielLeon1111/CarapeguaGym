import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/thousands_input_formatter.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/validators.dart';
import '../../data/models/stock_movement.dart';
import '../../data/models/stock_product.dart';
import '../../providers/repository_providers.dart';
import 'stock_style.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

Future<void> showProductFormSheet(BuildContext context, WidgetRef ref, {StockProduct? existing, List<String> categories = const [], VoidCallback? onSaved}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProductForm(existing: existing, categories: categories, onSaved: onSaved),
  );
}

const _newCategorySentinel = '__nueva__';

class _ProductForm extends ConsumerStatefulWidget {
  final StockProduct? existing;
  final List<String> categories;
  final VoidCallback? onSaved;
  const _ProductForm({this.existing, required this.categories, this.onSaved});

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final String _opId = newOpId();
  final String _stockOpId = newOpId();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _servingsCtrl = TextEditingController(text: widget.existing?.servingsPerUnit.toString() ?? '30');
  late final _priceCtrl = TextEditingController(text: widget.existing != null ? thousandsFormat.format(widget.existing!.salePrice) : '');
  late final _thresholdCtrl = TextEditingController(text: (widget.existing?.lowStockThreshold ?? 5).toString());
  late final _newCategoryCtrl = TextEditingController();
  final _initialQtyCtrl = TextEditingController();
  final _initialCostCtrl = TextEditingController();

  late StockUnitType _unitType = widget.existing?.unitType ?? StockUnitType.unidad;
  late String? _category = widget.existing?.category;
  bool _creatingCategory = false;
  late bool _expires = widget.existing?.expires ?? false;
  bool _hasInitialStock = false;
  DateTime? _initialExpiration;
  bool _saving = false;
  String? _error;

  List<String> get _allCategories {
    final set = {...defaultCategories, ...widget.categories};
    if (_category != null && _category != _newCategorySentinel) set.add(_category!);
    return set.toList()..sort();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _servingsCtrl, _priceCtrl, _thresholdCtrl, _newCategoryCtrl, _initialQtyCtrl, _initialCostCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final category = _creatingCategory ? _newCategoryCtrl.text.trim() : (_category ?? '');
    final price = ThousandsInputFormatter.parse(_priceCtrl.text);

    final error =
        Validators.requiredText(name, message: 'Escribí el nombre del producto.', maxLength: 80) ??
        (category.isEmpty ? 'Elegí o creá una categoría.' : null) ??
        (_unitType == StockUnitType.servicio ? Validators.intInRange(_servingsCtrl.text, field: '"Scoops por pote"', max: 1000) : null) ??
        Validators.amount(price, field: 'el precio de venta') ??
        Validators.intInRange(_thresholdCtrl.text, field: '"Aviso stock bajo"', min: 0, max: 100000) ??
        (_hasInitialStock ? Validators.intInRange(_initialQtyCtrl.text, field: '"Stock que tenés ahora"', max: 100000) : null);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(stockRepositoryProvider);
    final servings = _unitType == StockUnitType.servicio ? int.parse(_servingsCtrl.text.trim()) : 1;
    final product = StockProduct(
      id: widget.existing?.id ?? '',
      name: name,
      category: category,
      unitType: _unitType,
      servingsPerUnit: servings,
      salePrice: price,
      lowStockThreshold: int.parse(_thresholdCtrl.text.trim()),
      stockQty: widget.existing?.stockQty ?? 0,
      avgCost: widget.existing?.avgCost ?? 0,
      expires: _expires,
      active: widget.existing?.active ?? true,
    );
    try {
      String successMsg;
      if (widget.existing != null) {
        await repo.updateProduct(widget.existing!.id, product);
        successMsg = 'Producto actualizado.';
      } else {
        final created = await repo.createProduct(product, opId: _opId);
        final initialQty = _hasInitialStock ? (int.tryParse(_initialQtyCtrl.text.trim()) ?? 0) : 0;
        if (initialQty > 0) {
          // Carga inicial de stock (por ejemplo un pote ya abierto con lo que le queda).
          await repo.recordMovement(
            productId: created.id,
            tipo: StockMoveType.entrada,
            qty: initialQty,
            unitCost: ThousandsInputFormatter.parse(_initialCostCtrl.text),
            expiration: _initialExpiration,
            note: 'Carga inicial',
            opId: _stockOpId,
          );
          successMsg = 'Producto creado con $initialQty ${created.unitLabel} en stock.';
        } else {
          successMsg = 'Producto creado. Registrá una compra para cargar stock.';
        }
      }
      widget.onSaved?.call();
      if (mounted) {
        showSuccess(context, successMsg);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'guardar el producto'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isService = _unitType == StockUnitType.servicio;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing != null ? 'Editar producto' : 'Nuevo producto', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Whey Chocolate 2lb / Agua 500ml'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _creatingCategory ? _newCategorySentinel : _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                ..._allCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                const DropdownMenuItem(value: _newCategorySentinel, child: Text('➕ Nueva categoría...')),
              ],
              onChanged: (v) => setState(() {
                if (v == _newCategorySentinel) {
                  _creatingCategory = true;
                  _category = _newCategorySentinel;
                } else {
                  _creatingCategory = false;
                  _category = v;
                }
              }),
            ),
            if (_creatingCategory) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _newCategoryCtrl,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                decoration: const InputDecoration(labelText: 'Nombre de la nueva categoría', hintText: 'Ej: Bebidas, Guantes'),
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<StockUnitType>(
              segments: const [
                ButtonSegment(value: StockUnitType.unidad, label: Text('Por unidad'), icon: Icon(Icons.inventory_2_outlined)),
                ButtonSegment(value: StockUnitType.servicio, label: Text('Por scoop'), icon: Icon(Icons.icecream_outlined)),
              ],
              selected: {_unitType},
              onSelectionChanged: widget.existing != null ? null : (s) => setState(() => _unitType = s.first),
            ),
            if (widget.existing != null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('El tipo de venta no se puede cambiar una vez creado.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            if (isService)
              TextField(
                controller: _servingsCtrl,
                decoration: const InputDecoration(labelText: 'Scoops por pote', helperText: 'Cuántos servicios rinde un pote lleno'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              ),
            if (isService) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    decoration: InputDecoration(labelText: isService ? 'Precio por servicio' : 'Precio por unidad', prefixText: 'Gs. '),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _thresholdCtrl,
                    decoration: const InputDecoration(labelText: 'Aviso stock bajo'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Este producto vence?'),
              subtitle: const Text('Si lo activás, al comprar te pide la fecha de vencimiento'),
              value: _expires,
              onChanged: (v) => setState(() => _expires = v),
            ),
            if (widget.existing == null) ...[
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('¿Ya tenés stock de este producto?'),
                subtitle: Text(isService ? 'Ej: un pote ya abierto con la mitad usada' : 'Cargá lo que ya tenés ahora'),
                value: _hasInitialStock,
                onChanged: (v) => setState(() => _hasInitialStock = v),
              ),
              if (_hasInitialStock) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _initialQtyCtrl,
                        decoration: InputDecoration(
                          labelText: isService ? 'Servicios que quedan ahora' : 'Unidades que tenés',
                          helperText: isService ? 'Nuevo: poné ${_servingsCtrl.text.isEmpty ? 'los que trae' : _servingsCtrl.text}. Abierto: los que quedan' : null,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _initialCostCtrl,
                        decoration: InputDecoration(labelText: isService ? 'Costo por servicio' : 'Costo por unidad', prefixText: 'Gs. ', helperText: 'Opcional'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
                      ),
                    ),
                  ],
                ),
                if (_expires)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy_outlined),
                    title: const Text('Vencimiento'),
                    subtitle: Text(_initialExpiration == null ? 'Sin definir (opcional)' : _dateFmt.format(_initialExpiration!)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _initialExpiration ?? now,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 10),
                        helpText: 'Fecha de vencimiento',
                      );
                      if (picked != null) setState(() => _initialExpiration = picked);
                    },
                  ),
              ],
            ],
            InlineError(_error),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
