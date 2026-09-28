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
import 'stock_math.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

Future<void> showPurchaseSheet(BuildContext context, WidgetRef ref, StockProduct product, {VoidCallback? onSaved}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PurchaseSheet(product: product, onSaved: onSaved),
  );
}

class _PurchaseSheet extends ConsumerStatefulWidget {
  final StockProduct product;
  final VoidCallback? onSaved;
  const _PurchaseSheet({required this.product, this.onSaved});

  @override
  ConsumerState<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends ConsumerState<_PurchaseSheet> {
  final String _opId = newOpId();
  // Por unidad: packs × unidades por pack. Por servicio: potes.
  final _packsCtrl = TextEditingController(text: '1');
  final _perPackUnitsCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  final _availableCtrl = TextEditingController();
  DateTime? _expiration;
  bool _partial = false; // servicio: pote ya abierto/usado
  bool _saving = false;
  String? _error;

  StockProduct get _p => widget.product;
  bool get _isService => _p.isService;

  int get _packs => int.tryParse(_packsCtrl.text) ?? 0;
  int get _perPackUnits => int.tryParse(_perPackUnitsCtrl.text) ?? 0;
  int get _cost => ThousandsInputFormatter.parse(_costCtrl.text);

  // Cantidad base que ingresa y costo por unidad base.
  int get _fullServings => _packs * _p.servingsPerUnit;
  int get _qtyAdded {
    if (_isService) return _partial ? (int.tryParse(_availableCtrl.text) ?? 0) : _fullServings;
    return _packs * _perPackUnits;
  }

  int get _unitCost {
    if (_isService) return perUnitCost(packCost: _cost, unitsPerPack: _p.servingsPerUnit);
    return perUnitCost(packCost: _cost, unitsPerPack: _perPackUnits);
  }

  int get _newAvg => weightedAverage(stockBefore: _p.stockQty, avgBefore: _p.avgCost, qtyAdded: _qtyAdded, unitCost: _unitCost);

  @override
  void dispose() {
    for (final c in [_packsCtrl, _perPackUnitsCtrl, _costCtrl, _availableCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    String? error;
    if (_isService) {
      error = Validators.intInRange(_packsCtrl.text, field: '"Cantidad de potes"', max: 1000) ?? Validators.amount(_cost, field: 'el precio por pote');
      if (error == null && _partial) {
        error = Validators.intInRange(_availableCtrl.text, field: '"Servicios disponibles ahora"', max: _fullServings);
        if (_qtyAdded > _fullServings) error = 'No puede haber más de $_fullServings servicios (es lo que traen llenos).';
      }
    } else {
      error =
          Validators.intInRange(_packsCtrl.text, field: '"Cantidad de packs"', max: 10000) ??
          Validators.intInRange(_perPackUnitsCtrl.text, field: '"Unidades por pack"', max: 1000) ??
          Validators.amount(_cost, field: 'el precio por pack');
    }
    if (error == null && _p.expires && _expiration == null) {
      error = 'Este producto vence: elegí la fecha de vencimiento.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    // Aviso si vas a perder plata (costo por unidad ≥ precio de venta).
    if (_p.salePrice > 0 && _unitCost >= _p.salePrice) {
      final ok = await confirmAction(
        context,
        title: '¿Precio correcto?',
        message: 'El costo queda en ${formatGs(_unitCost)} por ${_p.unitLabelSingular}, pero lo vendés a ${formatGs(_p.salePrice)}. Vas a perder plata. ¿Seguir?',
        confirmLabel: 'Sí, está bien',
        cancelLabel: 'Corregir',
        icon: Icons.warning_amber_rounded,
      );
      if (!ok) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(stockRepositoryProvider).recordMovement(productId: _p.id, tipo: StockMoveType.entrada, qty: _qtyAdded, unitCost: _unitCost, expiration: _expiration, opId: _opId);
      widget.onSaved?.call();
      if (mounted) {
        showSuccess(context, 'Compra registrada: +$_qtyAdded ${_p.unitLabel}.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'registrar la compra'));
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
            Text('Registrar compra', style: Theme.of(context).textTheme.titleLarge),
            Text(_p.name, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            if (_isService) ..._serviceFields() else ..._unitFields(),
            if (_p.expires) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('Vencimiento'),
                subtitle: Text(_expiration == null ? 'Sin definir' : _dateFmt.format(_expiration!)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiration ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 10),
                    helpText: 'Fecha de vencimiento',
                  );
                  if (picked != null) setState(() => _expiration = picked);
                },
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [_kv('Ingresa', '$_qtyAdded ${_p.unitLabel}'), _kv('Costo por ${_p.unitLabelSingular}', formatGs(_unitCost)), _kv('Nuevo costo promedio', formatGs(_newAvg))]),
            ),
            InlineError(_error),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar compra'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _serviceFields() => [
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _packsCtrl,
            decoration: const InputDecoration(labelText: 'Cantidad de potes'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _costCtrl,
            decoration: const InputDecoration(labelText: 'Precio por pote', prefixText: 'Gs. '),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Ya está abierto / usado'),
      subtitle: const Text('Cargá cuántos servicios quedan realmente'),
      value: _partial,
      onChanged: (v) => setState(() {
        _partial = v;
        if (v && _availableCtrl.text.isEmpty) _availableCtrl.text = _fullServings.toString();
      }),
    ),
    if (_partial)
      TextField(
        controller: _availableCtrl,
        decoration: InputDecoration(labelText: 'Servicios disponibles ahora', helperText: 'De $_fullServings que traen llenos'),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
        onChanged: (_) => setState(() {}),
      ),
  ];

  List<Widget> _unitFields() => [
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _packsCtrl,
            decoration: const InputDecoration(labelText: 'Cantidad de packs', helperText: 'Si viene suelto, poné 1'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _perPackUnitsCtrl,
            decoration: const InputDecoration(labelText: 'Unidades por pack', helperText: 'Ej: pack de 6 → 6'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _costCtrl,
      decoration: const InputDecoration(labelText: 'Precio por pack', prefixText: 'Gs. ', helperText: 'Lo que pagaste por cada pack'),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
      onChanged: (_) => setState(() {}),
    ),
  ];

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: Colors.grey)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
