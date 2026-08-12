import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/api/d_api.dart';
import '../../../shared/widgets/app_shell.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await DApi.instance.loadSession();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.blue)),
      );
    }
    return DApi.instance.token == null ? const AuthScreen() : const AppShell();
  }
}
