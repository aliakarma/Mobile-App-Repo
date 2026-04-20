import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_application_intelligence_system/main.dart';

void main() {
  testWidgets('app launches with valid root state',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SmartApplicationIntelligenceSystemApp());
    await tester.pump(const Duration(milliseconds: 300));

    final hasLoginUi = find.text('Login').evaluate().isNotEmpty;
    final hasHomeUi = find.text('Dashboard').evaluate().isNotEmpty;
    final hasBootstrapLoader =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;

    expect(hasLoginUi || hasHomeUi || hasBootstrapLoader, isTrue);

    // Allow any startup timeout guards to settle so no timers remain pending.
    await tester.pump(const Duration(seconds: 3));
  });
}
