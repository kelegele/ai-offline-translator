import 'package:ai_offline_translator/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows model loading flow before translation', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    expect(find.text('AI 离线翻译'), findsOneWidget);
    expect(find.text('加载模型'), findsOneWidget);
    expect(find.text('下载模型'), findsOneWidget);
    expect(find.text('当前模型'), findsOneWidget);
    expect(find.text('未选择模型'), findsOneWidget);
    expect(find.text('GGUF 路径'), findsNothing);
    expect(find.textContaining('手动填写'), findsNothing);
  });
}
