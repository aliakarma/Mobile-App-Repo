import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/service_locator.dart';
import 'domain/repositories/applications_repository.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  runApp(const SmartApplicationIntelligenceSystemApp());
}

class SmartApplicationIntelligenceSystemApp extends StatefulWidget {
  const SmartApplicationIntelligenceSystemApp({
    super.key,
    this.authController,
    this.applicationsRepository,
  });

  final AuthController? authController;
  final ApplicationsRepository? applicationsRepository;

  @override
  State<SmartApplicationIntelligenceSystemApp> createState() =>
      _SmartApplicationIntelligenceSystemAppState();
}

class _SmartApplicationIntelligenceSystemAppState
    extends State<SmartApplicationIntelligenceSystemApp> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? AuthController();
    _authController.initialize();
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: AnimatedBuilder(
        animation: _authController,
        builder: (context, _) {
          return MaterialApp(
            title: 'Smart Application Intelligence System',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xFF0B7A75)),
              useMaterial3: true,
              inputDecorationTheme: const InputDecorationTheme(
                filled: true,
                fillColor: Color(0xFFF8FAFC),
              ),
            ),
            home: _buildRootScreen(),
          );
        },
      ),
    );
  }

  Widget _buildRootScreen() {
    switch (_authController.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.unauthenticated:
        return AuthGateScreen(authController: _authController);
      case AuthStatus.authenticated:
        final user = _authController.session?.user;
        return HomeScreen(
          onLogout: _authController.logout,
          accountName: user?.fullName ?? 'User',
          accountEmail: user?.email ?? '',
          applicationsRepository: widget.applicationsRepository,
        );
    }
  }
}
