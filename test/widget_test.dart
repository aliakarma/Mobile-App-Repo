import 'package:flutter_test/flutter_test.dart';

import 'package:smart_application_intelligence_system/main.dart';

void main() {
  testWidgets('app launches with main navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartApplicationIntelligenceSystemApp());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Opportunities'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
