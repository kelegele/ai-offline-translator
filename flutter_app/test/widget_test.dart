import 'package:ai_offline_translator/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows main translation UI', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    expect(find.text('AI离线翻译'), findsOneWidget);
    expect(find.text('未加载模型'), findsOneWidget);
    expect(find.text('英语'), findsAtLeast(1));
    expect(find.text('中文'), findsAtLeast(1));
    expect(find.text('译文'), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);

    expect(find.text('GGUF 路径'), findsNothing);
  });

  testWidgets('tapping capsule opens model sheet', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    await tester.tap(find.text('未加载模型'));
    await tester.pumpAndSettle();

    expect(find.text('模型'), findsOneWidget);
    expect(find.text('当前模型'), findsOneWidget);
    expect(find.text('未选择模型'), findsOneWidget);
    expect(find.text('导入'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
  });

  testWidgets('language menu matches HyMT 1.25bit supported languages', (
    tester,
  ) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    await tester.tap(find.text('英语').first);
    await tester.pumpAndSettle();

    expect(find.text('法语 (fr)'), findsOneWidget);
    expect(find.text('粤语'), findsNothing);
    expect(find.text('印地语'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('language_menu_scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(find.text('维吾尔语 (ug)'), findsOneWidget);
    expect(find.text('粤语'), findsNothing);
    expect(find.text('印地语'), findsNothing);
  });

  testWidgets('input caps meaningful characters at 200', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    await tester.enterText(find.byType(TextField), 'a' * 209);
    await tester.pump();

    expect(find.text('200/200'), findsOneWidget);
  });
}
