import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/validators.dart';
import '../../data/models/stock_movement.dart';
import '../../data/models/stock_product.dart';
import '../../providers/repository_providers.dart';

Future<void> showDamageSheet(BuildContext context, WidgetRef ref, StockProduct product, {VoidCallback? onSaved}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DamageSheet(product: product, onSaved: onSaved),
  );
}

class _DamageSheet extends ConsumerStatefulWidget {
  final StockProduct product;
  final VoidCallback? onSaved;
  const _DamageSheet({required this.product, this.onSaved});

  @override
  ConsumerState<_DamageSheet> createState() => _DamageSheetState();
}

class _DamageSheetState extends ConsumerState<_DamageSheet> {
  final String _opId = newOpId();
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  StockProduct get _p => widget.product;
  int get _qty => int.tryParse(_qtyCtrl.text) ?? 0;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final qtyError = Validators.intInRange(_qtyCtrl.text, field: '"Cantidad"', max: 100000);
    if (qtyError != null) {
      setState(() => _error = qtyError);
      return;
    }
    if (_qty > _p.stockQty) {
      setState(() => _error = 'Solo hay ${_p.stockQty} ${_p.unitLabel} en stock.');
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Dar de baja',
      message: 'Vas a descontar $_qty ${_p.unitLabel} de "${_p.name}" por avería/vencimiento. Esto no se puede deshacer.',
      confirmLabel: 'Dar de baja',
      destructive: true,
      icon: Icons.remove_circle_outline,
    );
    if (!ok) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(stockRepositoryProvider)
          .recordMovement(productId: _p.id, tipo: StockMoveType.averiado, qty: _qty, note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(), opId: _opId);
      widget.onSaved?.call();
      if (mounted) {
        showSuccess(context, 'Baja registrada: -$_qty ${_p.unitLabel}.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'registrar la baja'));
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
            Text('Registrar averiado / baja', style: Theme.of(context).textTheme.titleLarge),
            Text('${_p.name} · ${_p.stockQty} ${_p.unitLabel} en stock', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _qtyCtrl,
              decoration: InputDecoration(labelText: _p.isService ? 'Servicios a dar de baja' : 'Cantidad a dar de baja'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)', hintText: 'Ej: vencido, se cayó, roto'),
              inputFormatters: [LengthLimitingTextInputFormatter(120)],
            ),
            InlineError(_error),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Dar de baja'),
            ),
          ],
        ),
      ),
    );
  }
}
