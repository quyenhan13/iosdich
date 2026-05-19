#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TransifyrSubtitleView : UIView

- (void)start;
- (void)stop;
- (BOOL)hasActiveAudio;
- (BOOL)hasVisibleActivity;

@end

NS_ASSUME_NONNULL_END
