import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/validators.dart';
import '../../data/models/member.dart';
import '../../providers/repository_providers.dart';

const _allowedPhotoExt = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
const _maxPhotoBytes = 5 * 1024 * 1024;

class MemberFormScreen extends ConsumerStatefulWidget {
  final Member? existing;
  final String? prefilledName;
  const MemberFormScreen({super.key, this.existing, this.prefilledName});

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.fullName ?? _cleanPrefill(widget.prefilledName));
  late final _dniCtrl = TextEditingController(text: widget.existing?.dni ?? _dniFromPrefill(widget.prefilledName));
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
  late final _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
  late final _imeiCtrl = TextEditingController(text: widget.existing?.imei ?? '');
  late final _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime _joinDate = widget.existing?.joinDate ?? DateTime.now();
  String? _photoUrl;
  File? _pickedPhoto;
  bool _saving = false;
  bool _dirty = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.existing?.photoUrl;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _dniCtrl, _phoneCtrl, _emailCtrl, _imeiCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Si desde "Cobrar" se buscó un número, se asume que es un DNI y no un nombre.
  static String _cleanPrefill(String? v) => (v != null && RegExp(r'^[\d.\s]+$').hasMatch(v)) ? '' : (v ?? '');
  static String _dniFromPrefill(String? v) => (v != null && RegExp(r'^[\d.\s]+$').hasMatch(v)) ? v.replaceAll(RegExp(r'[^0-9]'), '') : '';

  bool get _isEditing => widget.existing != null;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
      if (picked == null) return;
      final ext = picked.path.split('.').last.toLowerCase();
      if (!_allowedPhotoExt.contains(ext)) {
        if (mounted) showError(context, 'Ese archivo no es una foto válida. Elegí una imagen JPG o PNG.');
        return;
      }
      final file = File(picked.path);
      if (await file.length() > _maxPhotoBytes) {
        if (mounted) showError(context, 'La foto pesa más de 5 MB. Elegí una más liviana.');
        return;
      }
      setState(() {
        _pickedPhoto = file;
        _dirty = true;
      });
    } catch (_) {
      if (mounted) showError(context, 'No se pudo abrir la galería. Revisá que la app tenga permiso para ver tus fotos.');
    }
  }

  Future<String?> _uploadPhotoIfNeeded(String memberId) async {
    if (_pickedPhoto == null) return _photoUrl;
    var ext = _pickedPhoto!.path.split('.').last.toLowerCase();
    if (!_allowedPhotoExt.contains(ext)) ext = 'jpg';
    final path = '$memberId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supa.storage.from('member-photos').upload(path, _pickedPhoto!, fileOptions: FileOptions(upsert: true, contentType: ext == 'png' ? 'image/png' : 'image/$ext'));
    return supa.storage.from('member-photos').getPublicUrl(path);
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _formError = 'Hay datos con errores (marcados en rojo). Corregilos para poder guardar.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(memberRepositoryProvider);
    final dni = Validators.normalizeDni(_dniCtrl.text);

    try {
      if (dni != null) {
        final dup = await repo.findByDni(dni, excludeId: widget.existing?.id);
        if (dup != null) {
          setState(() => _formError = 'Ya existe un socio con el DNI $dni: "${dup.fullName}". Si es la misma persona, buscala en la lista de socios en vez de crearla de nuevo.');
          return;
        }
      }

      if (_isEditing) {
        final id = widget.existing!.id;
        String? photoUrl = _photoUrl;
        String? photoWarning;
        try {
          photoUrl = await _uploadPhotoIfNeeded(id);
        } catch (e) {
          photoWarning = friendlyError(e);
        }
        // Se arma el socio completo (no copyWith) para que vaciar un campo
        // opcional realmente lo borre en la base.
        final old = widget.existing!;
        final updated = Member(
          id: old.id,
          fullName: _nameCtrl.text.trim(),
          dni: dni,
          phone: _nullIfEmpty(_phoneCtrl.text),
          email: _nullIfEmpty(_emailCtrl.text)?.toLowerCase(),
          imei: Validators.normalizeDni(_imeiCtrl.text),
          photoUrl: photoUrl,
          joinDate: _joinDate,
          frozen: old.frozen,
          notes: _nullIfEmpty(_notesCtrl.text),
          createdAt: old.createdAt,
          updatedAt: old.updatedAt,
          deletedAt: old.deletedAt,
        );
        final result = await repo.update(updated);
        if (!mounted) return;
        if (photoWarning != null) showWarning(context, 'Los datos se guardaron, pero la foto no: $photoWarning');
        Navigator.pop(context, result);
      } else {
        final draft = Member(
          id: '',
          fullName: _nameCtrl.text.trim(),
          dni: dni,
          phone: _nullIfEmpty(_phoneCtrl.text),
          email: _nullIfEmpty(_emailCtrl.text)?.toLowerCase(),
          imei: Validators.normalizeDni(_imeiCtrl.text),
          joinDate: _joinDate,
          frozen: false,
          notes: _nullIfEmpty(_notesCtrl.text),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final created = await repo.create(draft);
        // Una vez creado el socio, un fallo en la foto NO debe hacer que la
        // persona vuelva a tocar "Guardar" y cree un socio duplicado.
        var result = created;
        try {
          final photoUrl = await _uploadPhotoIfNeeded(created.id);
          if (photoUrl != null) result = await repo.update(created.copyWith(photoUrl: photoUrl));
        } catch (e) {
          if (mounted) showWarning(context, 'El socio se creó, pero la foto no se pudo subir. Podés agregarla después desde "Editar".');
        }
        if (!mounted) return;
        showSuccess(context, 'Socio "${result.fullName}" guardado.');
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) setState(() => _formError = friendlyError(e, action: 'guardar el socio'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onWillPop(bool didPop, Object? result) async {
    if (didPop) return;
    final leave = await confirmAction(
      context,
      title: '¿Salir sin guardar?',
      message: 'Hiciste cambios que todavía no guardaste. Si salís, se van a perder.',
      confirmLabel: 'Salir sin guardar',
      cancelLabel: 'Seguir editando',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (leave && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: _onWillPop,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Editar socio' : 'Nuevo socio')),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: _markDirty,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _saving ? null : _pickPhoto,
                  child: CircleAvatar(
                    radius: 44,
                    backgroundImage: _pickedPhoto != null ? FileImage(_pickedPhoto!) : (_photoUrl != null ? NetworkImage(_photoUrl!) : null) as ImageProvider?,
                    child: (_pickedPhoto == null && _photoUrl == null) ? const Icon(Icons.add_a_photo_outlined, size: 28) : null,
                  ),
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Tocá para elegir foto (opcional)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('member_name'),
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Nombre y apellido *', hintText: 'Ej: Juan Pérez', counterText: ''),
                validator: Validators.personName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('member_dni'),
                controller: _dniCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(13)],
                decoration: const InputDecoration(labelText: 'DNI / Cédula', hintText: 'Solo números, ej: 4567890'),
                validator: Validators.dni,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('member_phone'),
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')), LengthLimitingTextInputFormatter(20)],
                decoration: const InputDecoration(labelText: 'Teléfono (WhatsApp)', hintText: 'Ej: 0981 123456'),
                validator: Validators.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('member_email'),
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email', hintText: 'Ej: nombre@gmail.com'),
                validator: Validators.email,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('member_imei'),
                controller: _imeiCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(17)],
                decoration: const InputDecoration(labelText: 'IMEI', hintText: 'Solo números (opcional)'),
                validator: Validators.imei,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha de ingreso'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_joinDate)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _joinDate.isAfter(now) ? now : _joinDate,
                    firstDate: DateTime(2000),
                    lastDate: now,
                    helpText: 'Fecha en que el socio empezó',
                  );
                  if (picked != null) {
                    setState(() {
                      _joinDate = picked;
                      _dirty = true;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notas', hintText: 'Lesiones, objetivos, etc. (opcional)'),
                maxLines: 3,
                maxLength: 500,
                validator: Validators.notes,
              ),
              InlineError(_formError),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('member_save'),
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
