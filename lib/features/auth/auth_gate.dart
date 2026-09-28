import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../shell/home_shell.dart';
import 'biometric_lock_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final biometricEnabled = ref.read(biometricEnabledProvider).value ?? false;
      if (biometricEnabled && hasActiveSession) {
        setState(() => _unlocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const LoginScreen(),
      data: (state) {
        if (!hasActiveSession) {
          _unlocked = false;
          return const LoginScreen();
        }

        final biometricAsync = ref.watch(biometricEnabledProvider);
        return biometricAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          // Si no se puede leer la preferencia, se pide identidad igual (nunca se saltea el bloqueo).
          error: (_, _) => _unlocked ? const HomeShell() : BiometricLockScreen(onUnlocked: () => setState(() => _unlocked = true)),
          data: (biometricEnabled) {
            if (!biometricEnabled || _unlocked) {
              return const HomeShell();
            }
            return BiometricLockScreen(onUnlocked: () => setState(() => _unlocked = true));
          },
        );
      },
    );
  }
}
