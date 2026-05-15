import 'package:ai_offline_translator/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows translation UI with model capsule and lang bar', (
    tester,
  ) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    // Nav bar
    expect(find.text('AI 离线翻译'), findsOneWidget);
    expect(find.text('未加载'), findsOneWidget);

    // Language pill bar
    expect(find.text('英语'), findsAtLeast(1));
    expect(find.text('中文'), findsAtLeast(1));

    // Input + output areas
    expect(find.text('原文'), findsOneWidget);
    expect(find.text('译文'), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);

    // Bottom disclaimer
    // disclaimer is below the fold in SliverList, not visible without scrolling

    // Old elements should NOT be on main screen
    expect(find.text('加载模型'), findsNothing);
    expect(find.text('GGUF 路径'), findsNothing);
  });

  testWidgets('tapping capsule opens model sheet', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    await tester.tap(find.text('未加载'));
    await tester.pumpAndSettle();

    expect(find.text('模型管理'), findsOneWidget);
    expect(find.text('当前模型'), findsOneWidget);
    expect(find.text('未选择模型'), findsOneWidget);
    expect(find.text('导入'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
  });
}
