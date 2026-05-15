import 'package:ai_offline_translator/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders translator app shell', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    expect(find.text('AI Offline Translator'), findsOneWidget);
    expect(find.text('Local model ready'), findsOneWidget);
  });
}
