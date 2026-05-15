import 'package:ai_offline_translator/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows translation UI with model capsule', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    // Main screen elements
    expect(find.text('AI 离线翻译'), findsOneWidget);
    expect(find.text('未加载'), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);
    expect(find.text('原文'), findsOneWidget);
    expect(find.text('译文'), findsOneWidget);

    // Old model panel elements should NOT be visible on main screen
    expect(find.text('加载模型'), findsNothing);
    expect(find.text('下载模型'), findsNothing);
    expect(find.text('GGUF 路径'), findsNothing);
    expect(find.textContaining('手动填写'), findsNothing);
  });

  testWidgets('tapping capsule opens model sheet', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    // Find and tap the capsule button
    final capsule = find.text('未加载');
    expect(capsule, findsOneWidget);
    await tester.tap(capsule);
    await tester.pumpAndSettle();

    // Bottom sheet should show model management
    expect(find.text('模型管理'), findsOneWidget);
    expect(find.text('当前模型'), findsOneWidget);
    expect(find.text('未选择模型'), findsOneWidget);
    expect(find.text('导入'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
  });
}
