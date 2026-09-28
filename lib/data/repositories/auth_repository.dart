import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';

class AuthRepository {
  Session? get currentSession => supa.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => supa.auth.onAuthStateChange;

  Future<AuthResponse> signIn(String email, String password) {
    return supa.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => supa.auth.signOut();
}
