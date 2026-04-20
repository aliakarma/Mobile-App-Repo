import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _showLogin = true;

  void _openLogin() {
    if (_showLogin) return;
    setState(() {
      _showLogin = true;
    });
  }

  void _openSignUp() {
    if (!_showLogin) return;
    setState(() {
      _showLogin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetTween = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offsetTween.animate(animation),
            child: child,
          ),
        );
      },
      child: _showLogin
          ? LoginScreen(
              key: const ValueKey<String>('login_screen'),
              authController: widget.authController,
              onOpenSignUp: _openSignUp,
            )
          : SignUpScreen(
              key: const ValueKey<String>('signup_screen'),
              authController: widget.authController,
              onOpenLogin: _openLogin,
            ),
    );
  }
}
