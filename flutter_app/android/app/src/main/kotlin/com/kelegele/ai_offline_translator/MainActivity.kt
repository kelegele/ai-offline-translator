package com.kelegele.ai_offline_translator

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private lateinit var translatorHandler: TranslatorChannelHandler

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        translatorHandler = TranslatorChannelHandler(this)
        translatorHandler.register(flutterEngine)
    }
}
