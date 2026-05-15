#import <Foundation/Foundation.h>

@interface TranslatorBridge : NSObject
@property (nonatomic, readonly) BOOL isLoaded;
- (BOOL)loadWithPath:(NSString*)path nCtx:(NSInteger)nCtx nThreads:(NSInteger)nThreads;
- (NSString*)lastError;
- (void)unload;
- (void)translateText:(NSString*)text
       sourceLanguage:(NSString*)source
       targetLanguage:(NSString*)target
             completion:(void(^)(NSString* _Nullable, NSError* _Nullable))completion;
- (void)cancel;
- (NSString*)statusText;
@end
