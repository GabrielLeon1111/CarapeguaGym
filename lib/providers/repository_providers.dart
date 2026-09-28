import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_config.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/daily_pass_repository.dart';
import '../data/repositories/member_repository.dart';
import '../data/repositories/period_repository.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/stock_repository.dart';
import '../features/auth/biometric_service.dart';
import '../features/charge/daily_rate_store.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());
final memberRepositoryProvider = Provider((ref) => MemberRepository());
final planRepositoryProvider = Provider((ref) => PlanRepository());
final periodRepositoryProvider = Provider((ref) => PeriodRepository());
final settingsRepositoryProvider = Provider((ref) => SettingsRepository());
final stockRepositoryProvider = Provider((ref) => StockRepository());
final dailyPassRepositoryProvider = Provider((ref) => DailyPassRepository());
final dailyRateStoreProvider = Provider((ref) => DailyRateStore());
final biometricServiceProvider = Provider((ref) => BiometricService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

final biometricEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometricServiceProvider).isEnabled();
});

final biometricSupportedProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometricServiceProvider).isDeviceSupported();
});

bool get hasActiveSession => supa.auth.currentSession != null;
