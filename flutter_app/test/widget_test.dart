import 'package:ai_offline_translator/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders translator workspace controls', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    expect(find.text('AI Offline Translator'), findsOneWidget);
    expect(find.text('Local model ready'), findsOneWidget);
    expect(find.text('English'), findsWidgets);
    expect(find.text('Chinese'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('translates hello with mock service', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.text('Translate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('你好'), findsOneWidget);
  });
}
