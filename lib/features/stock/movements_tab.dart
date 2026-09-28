import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feedback.dart';
import '../../data/models/stock_movement.dart';
import '../../providers/repository_providers.dart';
import '../shared/client_picker.dart';

final _dtFmt = DateFormat('dd/MM/yy HH:mm');

final stockMovementsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(stockRepositoryProvider).getMovements();
});

class MovementsTab extends ConsumerWidget {
  const MovementsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stockMovementsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(stockMovementsProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: friendlyError(e, action: 'cargar los movimientos'),
          onRetry: () => ref.invalidate(stockMovementsProvider),
        ),
        data: (moves) {
          if (moves.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text('Todavía no hay movimientos.', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: moves.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _MovementCard(m: moves[i]),
          );
        },
      ),
    );
  }
}

class _MovementCard extends ConsumerWidget {
  final StockMovement m;
  const _MovementCard({required this.m});

  (Color, IconData, String) get _style => switch (m.tipo) {
    StockMoveType.entrada => (Colors.green, Icons.arrow_downward, '+'),
    StockMoveType.devolucion => (Colors.teal, Icons.undo, '+'),
    StockMoveType.salida => (Colors.blue, Icons.arrow_upward, '−'),
    StockMoveType.averiado => (Colors.orange.shade800, Icons.remove_circle_outline, '−'),
    StockMoveType.ajuste => (Colors.grey, Icons.tune, ''),
  };

  Future<void> _void(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: '¿Anular este movimiento?',
      message: 'Vas a anular ${m.tipo.label.toLowerCase()} de ${m.qty} en "${m.productName}". Se revierte el stock${m.tipo == StockMoveType.entrada ? ' y el costo' : ''}. ¿Seguro?',
      confirmLabel: 'Anular',
      destructive: true,
      icon: Icons.undo,
    );
    if (!ok) return;
    try {
      await ref.read(stockRepositoryProvider).voidMovement(m.id);
      ref.invalidate(stockMovementsProvider);
      if (context.mounted) showSuccess(context, 'Movimiento anulado.');
    } catch (e) {
      if (context.mounted) showError(context, friendlyError(e, action: 'anular el movimiento'));
    }
  }

  Future<void> _associate(BuildContext context, WidgetRef ref) async {
    final saved = await showClientAssociateSheet(context, title: 'Asociar cliente a la venta');
    if (saved == null) return;
    try {
      await ref.read(stockRepositoryProvider).associateClient(m.id, memberId: saved.memberId, customerName: saved.name);
      ref.invalidate(stockMovementsProvider);
      if (context.mounted) showSuccess(context, 'Cliente asociado.');
    } catch (e) {
      if (context.mounted) showError(context, friendlyError(e, action: 'asociar el cliente'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, icon, sign) = _style;
    final voided = m.isVoided;
    final canVoid = !voided && m.tipo != StockMoveType.ajuste;
    final canAssociate = !voided && m.tipo == StockMoveType.salida && m.memberId == null;

    return Opacity(
      opacity: voided ? 0.55 : 1,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.productName,
                                style: TextStyle(fontWeight: FontWeight.bold, decoration: voided ? TextDecoration.lineThrough : null),
                              ),
                            ),
                            if (voided)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
                                child: const Text(
                                  'ANULADO',
                                  style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        Text('${m.tipo.label} · ${_dtFmt.format(m.createdAt)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(
                    '$sign${m.qty}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (canVoid || canAssociate)
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'anular' ? _void(context, ref) : _associate(context, ref),
                      itemBuilder: (_) => [
                        if (canAssociate) const PopupMenuItem(value: 'asociar', child: Text('Asociar cliente')),
                        if (canVoid) const PopupMenuItem(value: 'anular', child: Text('Anular')),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  _chip('Stock: ${m.stockBefore} → ${m.stockAfter}'),
                  if (m.tipo == StockMoveType.entrada && m.unitCost != null) _chip('Costo u.: ${formatGs(m.unitCost!)}'),
                  if (m.avgBefore != m.avgAfter) _chip('Prom.: ${formatGs(m.avgBefore)} → ${formatGs(m.avgAfter)}'),
                  if (m.total != null) _chip('Total: ${formatGs(m.total!)}', bold: true),
                  if (m.profit != null) _chip('Ganancia: ${formatGs(m.profit!)}'),
                  if (m.paymentMethod != null) _chip(m.paymentMethod!.label),
                  if (m.customerName != null && m.customerName!.isNotEmpty) _chip('Cliente: ${m.customerName}'),
                  if (m.note != null && m.note!.isNotEmpty) _chip(m.note!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, {bool bold = false}) => Text(
    text,
    style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: bold ? null : Colors.black87),
  );
}
