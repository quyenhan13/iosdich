#import "DecoratedAppSceneView.h"
#import "TransifyrSubtitleView.h"
#import "ViewController.h"
#import "UIKitPrivate.h"
#include <math.h>

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
    [self applySubtitleOrientationAnimated:NO];

    // Keep the shell visually transparent; the old drag/title handle created a dark band over SpringBoard.
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self applySubtitleOrientationAnimated:NO];

    CGFloat buttonWidth = 76;
    CGFloat buttonHeight = 36;
    self.rotateButton.frame = CGRectMake(
        self.view.bounds.size.width - buttonWidth - 12,
        self.view.safeAreaInsets.top + 12,
        buttonWidth,
        buttonHeight
    );
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

- (void)applySubtitleOrientationAnimated:(BOOL)animated {
    if (!self.subtitleView) {
        return;
    }

    void (^changes)(void) = ^{
        CGSize size = self.view.bounds.size;
        CGFloat subtitleWidth = self.forceLandscape ? MIN(MAX(size.height - 32, 260), 720) : MIN(MAX(size.width - 32, 260), 520);
        CGFloat subtitleHeight = 92;

        self.subtitleView.bounds = CGRectMake(0, 0, subtitleWidth, subtitleHeight);
        self.subtitleView.transform = self.forceLandscape ? CGAffineTransformMakeRotation((CGFloat)M_PI_2) : CGAffineTransformIdentity;

        if (self.forceLandscape) {
            self.subtitleView.center = CGPointMake(size.width - 72, CGRectGetMidY(self.view.bounds));
        } else {
            self.subtitleView.center = CGPointMake(CGRectGetMidX(self.view.bounds), size.height - 120);
        }
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
    [self applySubtitleOrientationAnimated:YES];

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
