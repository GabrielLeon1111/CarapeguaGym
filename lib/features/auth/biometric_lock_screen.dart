import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import 'login_screen.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;

  const BiometricLockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _checking = false;
  bool _fallbackToManual = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAuthenticate());
  }

  Future<void> _tryAuthenticate() async {
    setState(() => _checking = true);
    final service = ref.read(biometricServiceProvider);
    final supported = await service.isDeviceSupported();
    final success = supported && await service.authenticate();
    if (!mounted) return;
    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _checking = false;
        _fallbackToManual = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fallbackToManual) {
      return LoginScreen(onLoginSuccess: widget.onUnlocked);
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fingerprint, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(_checking ? 'Verificando identidad...' : 'Desbloqueá la app'),
            const SizedBox(height: 24),
            TextButton(onPressed: () => setState(() => _fallbackToManual = true), child: const Text('Usar email y contraseña')),
          ],
        ),
      ),
    );
  }
}
