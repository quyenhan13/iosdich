#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SystemFrontBoardSceneHost : NSObject

@property(nonatomic, readonly) BOOL available;
@property(nonatomic, readonly) NSString *diagnosticSummary;

+ (instancetype)sharedHost;
- (BOOL)startWithWindowScene:(UIWindowScene *)windowScene;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
