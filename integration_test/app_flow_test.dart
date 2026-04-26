import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:smart_application_intelligence_system/core/di/service_locator.dart';
import 'package:smart_application_intelligence_system/domain/usecases/analyze_cv_usecase.dart';
import 'package:smart_application_intelligence_system/services/auth_controller.dart';

import 'mocks.dart';
import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const AnalyzeCvParams(
        cvText: 'dummy',
        targetOpportunity: 'dummy opportunity detail',
      ),
    );
  });

  testWidgets('login flow navigates to home', (tester) async {
    setupLocator(force: true);
    final api = MockAuthApiService();
    final storage = FakeAuthLocalStorage();
    final session = buildFakeSession();

    when(() => api.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          rememberMe: any(named: 'rememberMe'),
        )).thenAnswer((_) async => session);

    when(() => api.fetchCurrentUser(any()))
        .thenAnswer((_) async => session.user);

    final authController = AuthController(
      apiService: api,
      localStorage: storage,
    );

    await tester.pumpWidget(
      buildTestApp(
        authController: authController,
        applicationsRepository: InMemoryApplicationsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('adding application shows in list', (tester) async {
    setupLocator(force: true);
    final api = MockAuthApiService();
    final storage = FakeAuthLocalStorage();
    final session = buildFakeSession();

    when(() => api.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          rememberMe: any(named: 'rememberMe'),
        )).thenAnswer((_) async => session);

    when(() => api.fetchCurrentUser(any()))
        .thenAnswer((_) async => session.user);

    final authController = AuthController(apiService: api, localStorage: storage);
    final applicationsRepository = InMemoryApplicationsRepository();

    await tester.pumpWidget(
      buildTestApp(
        authController: authController,
        applicationsRepository: applicationsRepository,
      ),
    );
    await tester.pumpAndSettle();

    // Login
    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Go to Applications tab
    await tester.tap(find.text('Applications'));
    await tester.pumpAndSettle();

    // Empty state primary action opens dialog
    await tester.tap(find.text('Add Application'));
    await tester.pumpAndSettle();
    expect(find.text('Add Application'), findsWidgets);

    await tester.enterText(
      find.byType(TextFormField).first,
      'My Test Scholarship',
    );

    // Pick a deadline (today) and confirm.
    await tester.tap(find.text('Select a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('My Test Scholarship'), findsOneWidget);
  });

  testWidgets('CV analysis displays score ring results', (tester) async {
    final api = MockAuthApiService();
    final storage = FakeAuthLocalStorage();
    final session = buildFakeSession();

    when(() => api.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          rememberMe: any(named: 'rememberMe'),
        )).thenAnswer((_) async => session);

    when(() => api.fetchCurrentUser(any()))
        .thenAnswer((_) async => session.user);

    final authController = AuthController(apiService: api, localStorage: storage);

    final mockUseCase = MockAnalyzeCvUseCase();
    when(() => mockUseCase(any<AnalyzeCvParams>()))
        .thenAnswer((_) async => buildFakeCvAnalysis());

    setupLocator(force: true, analyzeCvUseCase: mockUseCase);

    await tester.pumpWidget(
      buildTestApp(
        authController: authController,
        applicationsRepository: InMemoryApplicationsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    // Login
    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Go to AI Tools tab -> CV Analyzer
    await tester.tap(find.text('AI Tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CV Analyzer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Scholarship in AI research with NLP focus',
    );
    final longCvText = List.filled(120, 'word').join(' ');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      longCvText,
    );

    final analyseButton = find.text('Analyse CV');
    await tester.ensureVisible(analyseButton);
    await tester.tap(analyseButton);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('82'), findsWidgets);
    expect(find.text('Overall Fit'), findsOneWidget);
  });
}

