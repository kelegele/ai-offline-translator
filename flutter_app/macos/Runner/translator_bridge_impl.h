#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TranslatorBridge : NSObject
@property (nonatomic, readonly) BOOL isLoaded;
- (BOOL)loadWithPath:(NSString*)path nCtx:(NSInteger)nCtx nThreads:(NSInteger)nThreads;
- (NSString* _Nullable)lastError;
- (void)unload;
- (void)translateText:(NSString*)text
       sourceLanguage:(NSString*)source
       targetLanguage:(NSString*)target
             completion:(void(^)(NSString* _Nullable, NSError* _Nullable))completion;
- (BOOL)beginTranslation:(NSString*)text
            sourceLanguage:(NSString*)source
            targetLanguage:(NSString*)target
                      error:(NSString* _Nullable* _Nullable)outError;
- (NSString* _Nullable)generateNextToken;
- (NSString*)generationOutputText;
- (void)cancel;
- (NSString*)statusText;
@end

NS_ASSUME_NONNULL_END
