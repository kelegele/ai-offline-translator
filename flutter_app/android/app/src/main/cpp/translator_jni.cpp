#include <jni.h>
#include <string>
#include <android/log.h>

#include "translator_engine.hpp"

#define LOG_TAG "TranslatorJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static TranslatorEngine* g_engine = nullptr;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorChannelHandler_nativeLoadModel(
    JNIEnv* env, jobject /* this */, jstring path, jint n_ctx, jint n_threads) {
  const char* path_str = env->GetStringUTFChars(path, nullptr);
  if (!path_str) return JNI_FALSE;

  TranslatorEngineConfig config;
  config.model_path = path_str;
  config.n_ctx = n_ctx;
  config.n_threads = n_threads;
  config.gpu_offload = false;

  env->ReleaseStringUTFChars(path, path_str);

  if (!g_engine) {
    g_engine = new TranslatorEngine();
  }

  bool ok = g_engine->load(config);
  if (!ok) {
    LOGE("Model load failed: %s", config.model_path.c_str());
  }
  return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jstring JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorChannelHandler_nativeTranslate(
    JNIEnv* env, jobject /* this */, jstring text, jstring source_lang, jstring target_lang) {
  if (!g_engine || !g_engine->is_loaded()) {
    return env->NewStringUTF("");
  }

  const char* text_str = env->GetStringUTFChars(text, nullptr);
  const char* src_str = env->GetStringUTFChars(source_lang, nullptr);
  const char* tgt_str = env->GetStringUTFChars(target_lang, nullptr);

  auto result = g_engine->translate(
      std::string(text_str),
      std::string(src_str),
      std::string(tgt_str));

  env->ReleaseStringUTFChars(text, text_str);
  env->ReleaseStringUTFChars(source_lang, src_str);
  env->ReleaseStringUTFChars(target_lang, tgt_str);

  return env->NewStringUTF(result.text.c_str());
}

JNIEXPORT void JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorChannelHandler_nativeCancel(
    JNIEnv* env, jobject /* this */) {
  if (g_engine) {
    g_engine->cancel();
  }
}

JNIEXPORT void JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorChannelHandler_nativeUnload(
    JNIEnv* env, jobject /* this */) {
  if (g_engine) {
    g_engine->unload();
  }
}

JNIEXPORT jboolean JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorChannelHandler_nativeIsLoaded(
    JNIEnv* env, jobject /* this */) {
  return (g_engine && g_engine->is_loaded()) ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"
