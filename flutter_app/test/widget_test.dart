import 'package:ai_offline_translator/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows main translation UI', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    expect(find.text('AI 离线翻译'), findsOneWidget);
    expect(find.text('未加载模型'), findsOneWidget);
    expect(find.text('英语'), findsAtLeast(1));
    expect(find.text('中文'), findsAtLeast(1));
    expect(find.text('译文'), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

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
}
