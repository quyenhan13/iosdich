#import "DecoratedAppSceneView.h"
#import "TransifyrSubtitleView.h"
#import "ViewController.h"
#import "UIKitPrivate.h"

@interface ViewController ()
@property(nonatomic) FBApplicationProcessLaunchTransaction *transaction;
@property(nonatomic) UIScenePresentationManager *presentationManager;
@property(nonatomic, strong) UIButton *rotateButton;
@property(nonatomic, strong) TransifyrSubtitleView *subtitleView;
@property(nonatomic, assign) BOOL forceLandscape;
@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.forceLandscape ? UIInterfaceOrientationMaskLandscapeRight : UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return self.forceLandscape ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationPortrait;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.title = nil;
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.opaque = NO;
    self.title = nil;
    self.forceLandscape = NO;

    CGFloat width = MIN(UIScreen.mainScreen.bounds.size.width - 32, 520);
    CGFloat height = 92;
    CGRect frame = CGRectMake(0, 0, width, height);
    TransifyrSubtitleView *subtitleView = [[TransifyrSubtitleView alloc] initWithFrame:frame];
    subtitleView.autoresizingMask = UIViewAutoresizingNone;
    self.subtitleView = subtitleView;
    [self.view addSubview:subtitleView];
    [subtitleView start];
    [self addRotateButton];
    [self layoutOverlayControlsAnimated:NO];

    // Keep the shell visually transparent; the old drag/title handle created a dark band over SpringBoard.
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutOverlayControlsAnimated:NO];
}

- (void)addRotateButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = UIColor.whiteColor;
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.34];
    button.layer.cornerRadius = 18;
    button.layer.masksToBounds = YES;
    [button setTitle:@"Ngang" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(toggleOrientation) forControlEvents:UIControlEventTouchUpInside];
    self.rotateButton = button;
    [self.view addSubview:button];
}

- (void)layoutOverlayControlsAnimated:(BOOL)animated {
    if (!self.subtitleView || !self.rotateButton) {
        return;
    }

    void (^changes)(void) = ^{
        CGSize size = self.view.bounds.size;
        UIEdgeInsets safeArea = self.view.safeAreaInsets;
        BOOL wideLayout = size.width > size.height;

        CGFloat maxSubtitleWidth = wideLayout ? 680 : 520;
        CGFloat subtitleWidth = MIN(MAX(size.width - 48, 260), maxSubtitleWidth);
        CGFloat subtitleHeight = wideLayout ? 70 : 92;
        CGFloat bottomInset = MAX(safeArea.bottom, 12);

        self.subtitleView.transform = CGAffineTransformIdentity;
        self.subtitleView.bounds = CGRectMake(0, 0, subtitleWidth, subtitleHeight);
        self.subtitleView.center = CGPointMake(size.width / 2.0, size.height - bottomInset - subtitleHeight / 2.0 - 18);

        CGFloat buttonWidth = 64;
        CGFloat buttonHeight = 34;
        self.rotateButton.transform = CGAffineTransformIdentity;
        self.rotateButton.frame = CGRectMake(
            size.width - safeArea.right - buttonWidth - 12,
            safeArea.top + 12,
            buttonWidth,
            buttonHeight
        );
    };

    if (animated) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:changes completion:nil];
    } else {
        changes();
    }
}

- (void)toggleOrientation {
    self.forceLandscape = !self.forceLandscape;
    [self.rotateButton setTitle:self.forceLandscape ? @"Doc" : @"Ngang" forState:UIControlStateNormal];
    [self setNeedsUpdateOfSupportedInterfaceOrientations];
    [self layoutOverlayControlsAnimated:YES];

    UIInterfaceOrientationMask mask = self.forceLandscape ? UIInterfaceOrientationMaskLandscapeRight : UIInterfaceOrientationMaskPortrait;
    UIDeviceOrientation deviceOrientation = self.forceLandscape ? UIDeviceOrientationLandscapeLeft : UIDeviceOrientationPortrait;

    if (@available(iOS 16.0, *)) {
        UIWindowScene *windowScene = self.view.window.windowScene;
        if (!windowScene) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:UIWindowScene.class]) {
                    windowScene = (UIWindowScene *)scene;
                    break;
                }
            }
        }
        UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:mask];
        [windowScene requestGeometryUpdateWithPreferences:preferences errorHandler:^(NSError *error) {
            [[UIDevice currentDevice] setValue:@(deviceOrientation) forKey:@"orientation"];
            [UIViewController attemptRotationToDeviceOrientation];
        }];
        [self.view.window setAutorotates:YES forceUpdateInterfaceOrientation:YES];
        [[UIDevice currentDevice] setValue:@(deviceOrientation) forKey:@"orientation"];
        [UIViewController attemptRotationToDeviceOrientation];
    } else {
        [self.view.window setAutorotates:YES forceUpdateInterfaceOrientation:YES];
        [[UIDevice currentDevice] setValue:@(deviceOrientation) forKey:@"orientation"];
        [UIViewController attemptRotationToDeviceOrientation];
    }

    [self.view setNeedsLayout];
}

@end
