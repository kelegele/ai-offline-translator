import 'package:ai_offline_translator/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders translator workspace controls', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    expect(find.text('AI 离线翻译'), findsOneWidget);
    expect(find.text('本地模型已就绪'), findsOneWidget);
    expect(find.text('英语'), findsWidgets);
    expect(find.text('中文'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);
  });

  testWidgets('translates hello with mock service', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.text('翻译'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('你好'), findsOneWidget);
  });
}
