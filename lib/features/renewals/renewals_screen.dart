import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/contact.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/ui_feedback.dart';
import '../../data/models/member_status.dart';
import '../../providers/repository_providers.dart';
import '../charge/charge_screen.dart';
import '../members/member_detail_screen.dart';
import '../members/members_screen.dart';

class _Bucket {
  final MemberStatus status;
  final Color color;
  final String label;
  const _Bucket(this.status, this.color, this.label);
}

final renewalsListProvider = FutureProvider.autoDispose((ref) async {
  final statuses = await ref.watch(memberRepositoryProvider).getStatuses();
  final today = DateTime.now();
  final buckets = <_Bucket>[];
  for (final s in statuses) {
    if (s.status == MemberStatusKind.vencido) {
      buckets.add(_Bucket(s, Colors.red, 'Vencido${(s.daysOverdue ?? 0) > 0 ? ' hace ${s.daysOverdue}d' : ''}'));
    } else if (s.status == MemberStatusKind.activo && s.endDate != null) {
      final daysUntil = s.endDate!.difference(DateTime(today.year, today.month, today.day)).inDays;
      if (daysUntil <= 7) {
        buckets.add(_Bucket(s, Colors.amber[800]!, 'Vence en ${daysUntil}d'));
      } else if (daysUntil <= 15) {
        buckets.add(_Bucket(s, Colors.green, 'Vence en ${daysUntil}d'));
      }
    }
  }
  buckets.sort((a, b) {
    final priority = {Colors.red: 0, Colors.amber[800]: 1, Colors.green: 2};
    final pa = priority[a.color] ?? 3;
    final pb = priority[b.color] ?? 3;
    if (pa != pb) return pa.compareTo(pb);
    return (a.status.endDate ?? DateTime(2100)).compareTo(b.status.endDate ?? DateTime(2100));
  });
  return buckets;
});

class RenewalsScreen extends ConsumerWidget {
  const RenewalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(renewalsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Por vencer / Vencidos')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(renewalsListProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(
            message: friendlyError(e, action: 'cargar los vencimientos'),
            onRetry: () => ref.invalidate(renewalsListProvider),
          ),
          data: (buckets) {
            if (buckets.isEmpty) {
              return const Center(child: Text('Nadie por vencer en los próximos 15 días 🎉'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: buckets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = buckets[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: b.color.withValues(alpha: 0.15),
                      child: Icon(Icons.circle, color: b.color, size: 14),
                    ),
                    title: Text(b.status.fullName),
                    subtitle: Text(b.label),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: b.status.memberId)));
                      ref.invalidate(renewalsListProvider);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Escribir por WhatsApp',
                          icon: const Icon(Icons.chat_outlined),
                          onPressed: () => openWhatsApp(context, b.status.phone, memberName: b.status.fullName),
                        ),
                        IconButton(
                          tooltip: 'Renovar / cobrar',
                          icon: const Icon(Icons.replay),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ChargeScreen(preselectedMemberId: b.status.memberId)));
                            ref.invalidate(renewalsListProvider);
                            ref.invalidate(memberStatusesProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
