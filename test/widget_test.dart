import 'package:flutter_test/flutter_test.dart';

import 'package:smart_application_intelligence_system/main.dart';

void main() {
  testWidgets('app launches with main navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartApplicationIntelligenceSystemApp());

    expect(find.text('Smart Application Intelligence System'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Opportunities'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
