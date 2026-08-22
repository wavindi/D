import 'package:flutter/material.dart';

import '../../../core/theme/racing_theme.dart';
import '../../../data/api/d_api.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/race_widgets.dart';

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
      Navigator.of(context).pushReplacement(slideUpRoute(const AppShell()));
    } catch (error) {
      setState(() => _error = error is StateError ? error.message : '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: RaceColors.muted),
        filled: true,
        fillColor: RaceColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: RaceColors.neonBlue.withValues(alpha: .28),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: RaceColors.neonBlue,
            width: 1.6,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              RaceColors.neonBlue.withValues(alpha: .12),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                children: [
                  RaceEntrance(
                    child: Container(
                      width: 92,
                      height: 92,
                      margin: const EdgeInsets.only(bottom: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: RaceColors.ink,
                        border: Border.all(
                          color: RaceColors.neonBlue,
                          width: 3,
                        ),
                        boxShadow: [RaceColors.glow(RaceColors.neonBlue, .7)],
                      ),
                      child: const Text(
                        'D',
                        style: TextStyle(
                          color: RaceColors.neonBlue,
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    _signup ? 'Create your driver account' : 'Sign in to race',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your trips are stored on the VPS database.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: RaceColors.muted),
                  ),
                  const SizedBox(height: 28),
                  RaceEntrance(
                    delay: const Duration(milliseconds: 80),
                    child: Column(
                      children: [
                        if (_signup)
                          TextField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            decoration: _decoration('Name'),
                          ),
                        if (_signup) const SizedBox(height: 12),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: _decoration('Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: _decoration('Password').copyWith(
                            helperText:
                                _signup ? 'Use at least 10 characters' : null,
                            helperStyle:
                                const TextStyle(color: RaceColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RaceColors.danger.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: RaceColors.danger.withValues(alpha: .5),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: RaceColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  RaceEntrance(
                    delay: const Duration(milliseconds: 160),
                    child: RaceButton(
                      label: _signup ? 'SIGN UP' : 'LOG IN',
                      icon: _signup ? Icons.person_add_alt_1 : Icons.login_rounded,
                      busy: _busy,
                      onPressed: _submit,
                    ),
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
                      style: const TextStyle(color: RaceColors.neonBlue),
                    ),
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
