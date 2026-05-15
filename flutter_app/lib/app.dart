import 'package:flutter/material.dart';

import 'design/app_theme.dart';
import 'features/translator/translator_page.dart';

class OfflineTranslatorApp extends StatelessWidget {
  const OfflineTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Offline Translator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const TranslatorPage(),
    );
  }
}
