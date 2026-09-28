import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/ui_feedback.dart';
import '../../providers/repository_providers.dart';
import 'member_detail_screen.dart';
import 'member_form_screen.dart';
import 'widgets/status_chip.dart';

final memberStatusesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(memberRepositoryProvider).getStatuses();
});

/// Socios que tienen algún período personalizado (sin paquete del catálogo).
final customMemberIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(periodRepositoryProvider).getCustomMemberIds();
});

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  String _search = '';
  bool _onlyCustom = false;

  @override
  Widget build(BuildContext context) {
    final asyncStatuses = ref.watch(memberStatusesProvider);
    final customIds = ref.watch(customMemberIdsProvider).value ?? const <String>{};
    final search = _search;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Socios'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Buscar por nombre o DNI', prefixIcon: Icon(Icons.search), isDense: true),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(label: const Text('Todos'), selected: !_onlyCustom, onSelected: (_) => setState(() => _onlyCustom = false)),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Personalizados'), selected: _onlyCustom, onSelected: (_) => setState(() => _onlyCustom = true)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agregar socio',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const MemberFormScreen()));
          ref.invalidate(memberStatusesProvider);
          ref.invalidate(customMemberIdsProvider);
        },
        child: const Icon(Icons.person_add_alt),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(memberStatusesProvider);
          ref.invalidate(customMemberIdsProvider);
        },
        child: asyncStatuses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(
            message: friendlyError(e, action: 'cargar los socios'),
            onRetry: () => ref.invalidate(memberStatusesProvider),
          ),
          data: (statuses) {
            final base = _onlyCustom ? statuses.where((s) => customIds.contains(s.memberId)).toList() : statuses;
            final filtered = search.isEmpty
                ? base
                : base.where((s) {
                    final q = search.trim().toLowerCase();
                    return s.fullName.toLowerCase().contains(q) || (s.dni ?? '').toLowerCase().contains(q);
                  }).toList();

            if (statuses.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Todavía no hay socios.\nTocá el botón + para agregar el primero.', textAlign: TextAlign.center)),
                ],
              );
            }
            if (_onlyCustom && base.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No hay socios con membresía personalizada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }
            if (filtered.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('No hay socios que coincidan con "$search".\nRevisá cómo lo escribiste o buscá por DNI.', textAlign: TextAlign.center)),
                ],
              );
            }
            return ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: s.photoUrl != null ? NetworkImage(s.photoUrl!) : null,
                    child: s.photoUrl == null ? Text(s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?') : null,
                  ),
                  title: Text(s.fullName),
                  subtitle: Text(s.dni ?? s.phone ?? ''),
                  trailing: StatusChip(status: s.status, daysOverdue: s.daysOverdue),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: s.memberId)));
                    ref.invalidate(memberStatusesProvider);
                    ref.invalidate(customMemberIdsProvider);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
