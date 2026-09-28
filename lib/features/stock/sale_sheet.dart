import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/thousands_input_formatter.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/validators.dart';
import '../../data/models/payment_method.dart';
import '../../data/models/stock_movement.dart';
import '../../data/models/stock_product.dart';
import '../../providers/repository_providers.dart';
import '../shared/client_picker.dart';

Future<void> showSaleSheet(BuildContext context, WidgetRef ref, StockProduct product, {VoidCallback? onSaved}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SaleSheet(product: product, onSaved: onSaved),
  );
}

class _SaleSheet extends ConsumerStatefulWidget {
  final StockProduct product;
  final VoidCallback? onSaved;
  const _SaleSheet({required this.product, this.onSaved});

  @override
  ConsumerState<_SaleSheet> createState() => _SaleSheetState();
}

class _SaleSheetState extends ConsumerState<_SaleSheet> {
  final String _opId = newOpId();
  final _qtyCtrl = TextEditingController(text: '1');
  late final _priceCtrl = TextEditingController(text: thousandsFormat.format(widget.product.salePrice));
  PaymentMethod _paymentMethod = PaymentMethod.efectivo;
  ClientRef _client = const ClientRef();
  bool _priceEdited = false;
  bool _saving = false;
  String? _error;

  StockProduct get _p => widget.product;
  int get _qty => int.tryParse(_qtyCtrl.text) ?? 0;
  int get _price => ThousandsInputFormatter.parse(_priceCtrl.text);
  int get _total => _qty * _price;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _setWholePote() {
    _qtyCtrl.text = _p.servingsPerUnit.toString();
    if (!_priceEdited) _priceCtrl.text = thousandsFormat.format(_p.salePrice);
    setState(() {});
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final qtyError = Validators.intInRange(_qtyCtrl.text, field: _p.isService ? '"Servicios"' : '"Cantidad"', max: 100000);
    if (qtyError != null) {
      setState(() => _error = qtyError);
      return;
    }
    if (_qty > _p.stockQty) {
      setState(() => _error = 'Solo hay ${_p.stockQty} ${_p.unitLabel} en stock. Bajá la cantidad o registrá una compra.');
      return;
    }
    if (_price > Validators.maxAmount) {
      setState(() => _error = 'El precio es demasiado alto. ¿Pusiste ceros de más?');
      return;
    }
    if (_price == 0) {
      final ok = await confirmAction(
        context,
        title: '¿Venta sin cobrar?',
        message: 'El precio está en Gs. 0. Descuenta stock pero no suma ingresos. ¿Es una cortesía?',
        confirmLabel: 'Sí, sin cargo',
        cancelLabel: 'Poner precio',
        icon: Icons.warning_amber_rounded,
      );
      if (!ok) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(stockRepositoryProvider)
          .recordMovement(
            productId: _p.id,
            tipo: StockMoveType.salida,
            qty: _qty,
            salePrice: _price,
            paymentMethod: _paymentMethod,
            memberId: _client.memberId,
            customerName: _client.name,
            opId: _opId,
          );
      widget.onSaved?.call();
      if (mounted) {
        showSuccess(context, 'Venta registrada: ${formatGs(_total)}.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'registrar la venta'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Vender / cobrar', style: Theme.of(context).textTheme.titleLarge),
            Text('${_p.name} · ${_p.stockQty} ${_p.unitLabel} en stock', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    decoration: InputDecoration(labelText: _p.isService ? 'Servicios' : 'Cantidad'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    decoration: InputDecoration(labelText: _p.isService ? 'Precio por servicio' : 'Precio por unidad', prefixText: 'Gs. '),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
                    onChanged: (_) {
                      _priceEdited = true;
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            if (_p.isService)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(onPressed: _setWholePote, icon: const Icon(Icons.local_drink_outlined, size: 18), label: Text('Vender pote entero (${_p.servingsPerUnit} servicios)')),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Método de pago'),
              items: PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.label))).toList(),
              onChanged: (m) => setState(() => _paymentMethod = m ?? _paymentMethod),
            ),
            const SizedBox(height: 8),
            ClientPicker(onChanged: (c) => _client = c),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total a cobrar', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(formatGs(_total), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            InlineError(_error),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Cobrar ${formatGs(_total)}'),
            ),
          ],
        ),
      ),
    );
  }
}
