import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/api/d_api.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/led_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signup) {
        await DApi.instance.signup(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await DApi.instance.login(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        slideUpRoute(const AppShell()),
      );
    } catch (error) {
      setState(() => _error = error is StateError ? error.message : '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              children: [
                const Text(
                  'D',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _signup ? 'Create your driver account' : 'Sign in to save trips',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your trips are stored on the VPS database.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                if (_signup)
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Name'),
                  ),
                if (_signup) const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(hintText: 'Password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 22),
                LedButton(
                  label: _signup ? 'SIGN UP' : 'LOG IN',
                  icon: _signup ? Icons.person_add_alt_1 : Icons.login_rounded,
                  busy: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _signup = !_signup;
                            _error = null;
                          }),
                  child: Text(
                    _signup
                        ? 'Already have an account? Log in'
                        : 'New here? Create an account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
