import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';

class FitnessGymApp extends StatelessWidget {
  const FitnessGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Fitness Gym', debugShowCheckedModeBanner: false, theme: AppTheme.light(), darkTheme: AppTheme.light(), themeMode: ThemeMode.light, home: const AuthGate());
  }
}
