#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TransifyrSubtitleStore : NSObject

- (NSString *)currentTranslation;
- (BOOL)hasFreshTranslation;
- (BOOL)hasActiveAudio;
- (BOOL)hasVisibleActivity;

@end

NS_ASSUME_NONNULL_END
