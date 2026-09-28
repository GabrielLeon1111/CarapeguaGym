import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/ui_feedback.dart';
import '../../data/models/app_settings.dart';
import '../../providers/repository_providers.dart';
import '../notifications/notification_service.dart';

final appSettingsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(settingsRepositoryProvider).get();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _biometricEnabled;
  bool _biometricSupported = true;
  bool _savingSettings = false;
  // Valor del slider mientras se arrastra (se guarda recién al soltar).
  double? _dragBefore;
  double? _dragOverdue;

  @override
  void initState() {
    super.initState();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final service = ref.read(biometricServiceProvider);
    final enabled = await service.isEnabled();
    final supported = await service.isDeviceSupported();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _biometricSupported = supported;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !_biometricSupported) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este dispositivo no tiene biometría configurada')));
      return;
    }
    if (value) {
      // Se verifica la huella/rostro antes de activar, para que nadie quede
      // bloqueado con una biometría que no funciona.
      final ok = await ref.read(biometricServiceProvider).authenticate();
      if (!ok) {
        if (mounted) showError(context, 'No se pudo verificar tu huella/rostro. El desbloqueo biométrico NO se activó.');
        return;
      }
    }
    try {
      await ref.read(biometricServiceProvider).setEnabled(value);
      if (!mounted) return;
      setState(() => _biometricEnabled = value);
      ref.invalidate(biometricEnabledProvider);
      showSuccess(context, value ? 'Desbloqueo biométrico activado.' : 'Desbloqueo biométrico desactivado.');
    } catch (_) {
      if (mounted) showError(context, 'No se pudo cambiar el ajuste de seguridad. Intentá de nuevo.');
    }
  }

  Future<void> _updateSettings(AppSettings Function(AppSettings) update) async {
    if (_savingSettings) return;
    setState(() => _savingSettings = true);
    try {
      final current = await ref.read(settingsRepositoryProvider).get();
      await ref.read(settingsRepositoryProvider).update(update(current));
      ref.invalidate(appSettingsProvider);
    } catch (e) {
      if (mounted) showError(context, friendlyError(e, action: 'guardar la configuración'));
      return;
    } finally {
      if (mounted) {
        setState(() {
          _savingSettings = false;
          _dragBefore = null;
          _dragOverdue = null;
        });
      }
    }
    try {
      await NotificationService.instance.rescheduleAll(ref.read(memberRepositoryProvider), ref.read(settingsRepositoryProvider));
    } catch (_) {
      if (mounted) showWarning(context, 'Se guardó la configuración, pero no se pudieron reprogramar los avisos. Se reintentará al abrir la app.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Seguridad', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Desbloqueo biométrico'),
            subtitle: Text(_biometricSupported ? 'Face ID / huella para entrar más rápido' : 'No disponible en este dispositivo'),
            value: _biometricEnabled ?? false,
            onChanged: _biometricEnabled == null ? null : _toggleBiometric,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          asyncSettings.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorRetry(
              message: friendlyError(e, action: 'cargar la configuración'),
              onRetry: () => ref.invalidate(appSettingsProvider),
            ),
            data: (s) => Column(
              children: [
                SwitchListTile(
                  title: const Text('Aviso de vencimiento próximo'),
                  subtitle: Text('${(_dragBefore?.round() ?? s.notifyBeforeDueDays)} días antes'),
                  value: s.notifyBeforeDueDays > 0,
                  onChanged: _savingSettings ? null : (v) => _updateSettings((c) => c.copyWith(notifyBeforeDueDays: v ? 3 : 0)),
                ),
                if (s.notifyBeforeDueDays > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      value: (_dragBefore ?? s.notifyBeforeDueDays.toDouble()).clamp(1, 14),
                      min: 1,
                      max: 14,
                      divisions: 13,
                      label: '${(_dragBefore ?? s.notifyBeforeDueDays.toDouble()).round()} días',
                      onChanged: _savingSettings ? null : (v) => setState(() => _dragBefore = v),
                      onChangeEnd: (v) => _updateSettings((c) => c.copyWith(notifyBeforeDueDays: v.round())),
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Aviso el día del vencimiento'),
                  value: s.notifyOnDueDay,
                  onChanged: _savingSettings ? null : (v) => _updateSettings((c) => c.copyWith(notifyOnDueDay: v)),
                ),
                SwitchListTile(
                  title: const Text('Aviso de socio moroso'),
                  subtitle: Text('${(_dragOverdue?.round() ?? s.notifyOverdueDays)} días de atraso'),
                  value: s.notifyOverdueDays > 0,
                  onChanged: _savingSettings ? null : (v) => _updateSettings((c) => c.copyWith(notifyOverdueDays: v ? 1 : 0)),
                ),
                if (s.notifyOverdueDays > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      value: (_dragOverdue ?? s.notifyOverdueDays.toDouble()).clamp(1, 14),
                      min: 1,
                      max: 14,
                      divisions: 13,
                      label: '${(_dragOverdue ?? s.notifyOverdueDays.toDouble()).round()} días',
                      onChanged: _savingSettings ? null : (v) => setState(() => _dragOverdue = v),
                      onChangeEnd: (v) => _updateSettings((c) => c.copyWith(notifyOverdueDays: v.round())),
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Resumen diario de ingresos'),
                  value: s.notifyDailySummary,
                  subtitle: const Text('Todos los días a las 20:00'),
                  onChanged: _savingSettings ? null : (v) => _updateSettings((c) => c.copyWith(notifyDailySummary: v)),
                ),
                SwitchListTile(
                  title: const Text('Resumen semanal de ingresos'),
                  value: s.notifyWeeklySummary,
                  subtitle: const Text('Domingos a las 20:00'),
                  onChanged: _savingSettings ? null : (v) => _updateSettings((c) => c.copyWith(notifyWeeklySummary: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
