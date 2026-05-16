#import "translator_bridge_impl.h"
#include "translator_engine.hpp"

@interface TranslatorBridge () {
  TranslatorEngine* _engine;
  NSString* _lastError;
}
@end

@implementation TranslatorBridge

- (instancetype)init {
  self = [super init];
  if (self) {
    _engine = new TranslatorEngine();
    _lastError = nil;
  }
  return self;
}

- (void)dealloc {
  delete _engine;
}

- (BOOL)isLoaded {
  return _engine->is_loaded() ? YES : NO;
}

- (NSString*)lastError { return _lastError; }

- (BOOL)loadWithPath:(NSString*)path nCtx:(NSInteger)nCtx nThreads:(NSInteger)nThreads {
  TranslatorEngineConfig cfg;
  cfg.model_path = std::string([path UTF8String]);
  cfg.n_ctx = (int)nCtx;
  cfg.n_threads = (int)nThreads;
  cfg.gpu_offload = false;

  if (_engine->load(cfg)) {
    _lastError = nil;
    return YES;
  }
  _lastError = @"模型加载失败";
  return NO;
}

- (void)unload {
  _engine->unload();
}

- (void)translateText:(NSString*)text
       sourceLanguage:(NSString*)source
       targetLanguage:(NSString*)target
             completion:(void(^)(NSString* _Nullable, NSError* _Nullable))completion {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    auto result = self->_engine->translate(
        std::string([text UTF8String]),
        std::string([source UTF8String]),
        std::string([target UTF8String]));

    dispatch_async(dispatch_get_main_queue(), ^{
      if (!result.error.empty() && !result.cancelled) {
        NSError* err = [NSError errorWithDomain:@"Translator" code:2
                                       userInfo:@{NSLocalizedDescriptionKey:
                                                   [NSString stringWithUTF8String:result.error.c_str()]}];
        completion(nil, err);
      } else if (result.cancelled) {
        completion(@"", nil);
      } else {
        completion([NSString stringWithUTF8String:result.text.c_str()], nil);
      }
    });
  });
}

- (BOOL)beginTranslation:(NSString*)text sourceLanguage:(NSString*)source targetLanguage:(NSString*)target error:(NSString**)outError {
  auto result = self->_engine->begin_translation(
      std::string([text UTF8String]),
      std::string([source UTF8String]),
      std::string([target UTF8String]));
  if (!result.error.empty()) {
    if (outError) {
      *outError = [NSString stringWithUTF8String:result.error.c_str()];
    }
    return NO;
  }
  return YES;
}

- (NSString*)generateNextToken {
  auto token = self->_engine->generate_next_token();
  if (!token.error.empty()) {
    return [NSString stringWithUTF8String:token.error.c_str()];
  }
  if (token.done || token.cancelled) {
    return nil;
  }
  if (token.piece.empty()) {
    return nil;
  }
  return [NSString stringWithUTF8String:token.piece.c_str()];
}

- (NSString*)generationOutputText {
  return [NSString stringWithUTF8String:self->_engine->generation_output_text().c_str()];
}

- (void)cancel {
  _engine->cancel();
}

- (NSString*)statusText {
  return [NSString stringWithUTF8String:_engine->status_text().c_str()];
}

@end
