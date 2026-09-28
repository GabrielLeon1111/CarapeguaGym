import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/validators.dart';
import '../../providers/repository_providers.dart';

const _lastEmailKey = 'last_login_email';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreLastEmail();
  }

  /// Recuerda el último email usado en ESTE dispositivo (no se expone en el código).
  Future<void> _restoreLastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_lastEmailKey);
      if (last != null && mounted && _emailCtrl.text.isEmpty) _emailCtrl.text = last;
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailCtrl.text.trim().toLowerCase();
    try {
      await ref.read(authRepositoryProvider).signIn(email, _passwordCtrl.text);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastEmailKey, email);
      } catch (_) {}
      await _maybeOfferBiometrics();
      widget.onLoginSuccess?.call();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'iniciar sesión'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _maybeOfferBiometrics() async {
    final service = ref.read(biometricServiceProvider);
    final alreadyEnabled = await service.isEnabled();
    if (alreadyEnabled) return;
    final supported = await service.isDeviceSupported();
    if (!supported || !mounted) return;

    final wantsIt = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.fingerprint, size: 40),
        title: const Text('¿Activar Face ID / huella?'),
        content: const Text('La próxima vez vas a poder entrar más rápido, sin escribir tu contraseña.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Activar')),
        ],
      ),
    );
    if (wantsIt == true) {
      await service.setEnabled(true);
      ref.invalidate(biometricEnabledProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipOval(child: Image.asset('assets/images/logo.jpeg', width: 150, height: 150, fit: BoxFit.cover)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Panel del administrador',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) => Validators.email(v, required: true),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
                    ),
                    autofillHints: const [AutofillHints.password],
                    validator: (v) => (v == null || v.isEmpty) ? 'Escribí tu contraseña.' : null,
                    onFieldSubmitted: (_) => _loading ? null : _submit(),
                  ),
                  InlineError(_error),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Ingresar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
