import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/member.dart';
import '../../providers/repository_providers.dart';
import '../members/member_form_screen.dart';

/// Referencia opcional a un cliente: un socio enlazado ([memberId]) o un nombre
/// suelto escrito a mano. Todo puede quedar vacío.
class ClientRef {
  final String? memberId;
  final String? name;
  final String? phone;
  const ClientRef({this.memberId, this.name, this.phone});

  bool get isEmpty => memberId == null && (name == null || name!.trim().isEmpty);
}

/// Hoja modal para elegir/crear un cliente y devolver la selección (o null).
Future<ClientRef?> showClientAssociateSheet(BuildContext context, {String title = 'Asociar cliente'}) {
  ClientRef current = const ClientRef();
  return showModalBottomSheet<ClientRef>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 16),
          ClientPicker(onChanged: (c) => current = c),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(ctx, current.isEmpty ? null : current), child: const Text('Guardar')),
        ],
      ),
    ),
  );
}

/// Campo para elegir cliente: buscás un socio ya cargado y lo enlazás, o
/// escribís un nombre suelto. Siempre opcional.
class ClientPicker extends ConsumerStatefulWidget {
  final ValueChanged<ClientRef> onChanged;
  final ClientRef? initial;
  const ClientPicker({super.key, required this.onChanged, this.initial});

  @override
  ConsumerState<ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<ClientPicker> {
  late final _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.initial?.phone ?? '');
  Timer? _debounce;
  List<Member> _results = [];
  bool _searching = false;
  Member? _linked; // socio enlazado (si eligió uno de la lista)

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    if (_linked != null) {
      widget.onChanged(ClientRef(memberId: _linked!.id, name: _linked!.fullName, phone: _phoneCtrl.text.trim().isEmpty ? _linked!.phone : _phoneCtrl.text.trim()));
    } else {
      final name = _nameCtrl.text.trim();
      widget.onChanged(ClientRef(name: name.isEmpty ? null : name, phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()));
    }
  }

  void _onNameChanged(String term) {
    if (_linked != null) {
      setState(() => _linked = null); // volvió a escribir: se desenlaza
    }
    _emit();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(term));
  }

  Future<void> _search(String term) async {
    final t = term.trim();
    if (t.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await ref.read(memberRepositoryProvider).search(t);
      if (!mounted) return;
      setState(() {
        _results = res;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _link(Member m) {
    FocusScope.of(context).unfocus();
    setState(() {
      _linked = m;
      _nameCtrl.text = m.fullName;
      if (m.phone != null && _phoneCtrl.text.trim().isEmpty) _phoneCtrl.text = m.phone!;
      _results = [];
    });
    _emit();
  }

  void _clear() {
    setState(() {
      _linked = null;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _results = [];
    });
    _emit();
  }

  Future<void> _createMember() async {
    final created = await Navigator.push<Member>(context, MaterialPageRoute(builder: (_) => MemberFormScreen(prefilledName: _nameCtrl.text.trim())));
    if (created != null && mounted) _link(created);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('client_name'),
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'Cliente (opcional)',
            hintText: 'Buscá un socio o escribí un nombre',
            prefixIcon: Icon(_linked != null ? Icons.link : Icons.search, color: _linked != null ? Colors.green : null),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (_nameCtrl.text.isNotEmpty ? IconButton(tooltip: 'Quitar', icon: const Icon(Icons.clear), onPressed: _clear) : null),
            helperText: _linked != null ? 'Enlazado al socio ${_linked!.fullName} ✓' : null,
            helperStyle: const TextStyle(color: Colors.green),
          ),
          onChanged: _onNameChanged,
        ),
        if (_results.isNotEmpty && _linked == null)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              children: _results
                  .take(6)
                  .map(
                    (m) => ListTile(
                      dense: true,
                      leading: CircleAvatar(backgroundColor: scheme.primaryContainer, child: Text(m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : '?')),
                      title: Text(m.fullName),
                      subtitle: Text(m.dni ?? m.phone ?? ''),
                      onTap: () => _link(m),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_linked == null && !_searching && _nameCtrl.text.trim().isNotEmpty && _results.isEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            color: scheme.secondaryContainer.withValues(alpha: 0.5),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.person_add_alt),
              title: Text('Registrar "${_nameCtrl.text.trim()}" como socio'),
              subtitle: const Text('O dejalo así para cobrar sin registrarlo'),
              onTap: _createMember,
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('client_phone'),
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}
