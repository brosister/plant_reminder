// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:plant_reminder/main.dart';

void main() {
  testWidgets('plant reminder home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PlantReminderApp());

    expect(find.text('식물 물주기 알리미'), findsOneWidget);
    expect(find.text('식집사 루틴'), findsOneWidget);
    expect(find.text('운영 기능'), findsOneWidget);
  });
}
