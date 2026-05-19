#import "DecoratedAppSceneView.h"
#import "TransifyrSubtitleView.h"
#import "ViewController.h"

@interface ViewController ()
@property(nonatomic) FBApplicationProcessLaunchTransaction *transaction;
@property(nonatomic) UIScenePresentationManager *presentationManager;
@property(nonatomic, strong) UIButton *rotateButton;
@property(nonatomic, assign) BOOL forceLandscape;
@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.forceLandscape ? UIInterfaceOrientationMaskLandscape : UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate {
    return YES;
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
    subtitleView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds) - 120);
    subtitleView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:subtitleView];
    [subtitleView start];
    [self addRotateButton];

    // Keep the shell visually transparent; the old drag/title handle created a dark band over SpringBoard.
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
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

- (void)toggleOrientation {
    self.forceLandscape = !self.forceLandscape;
    [self.rotateButton setTitle:self.forceLandscape ? @"Doc" : @"Ngang" forState:UIControlStateNormal];
    [self setNeedsUpdateOfSupportedInterfaceOrientations];

    UIInterfaceOrientationMask mask = self.forceLandscape ? UIInterfaceOrientationMaskLandscapeRight : UIInterfaceOrientationMaskPortrait;
    UIInterfaceOrientation orientation = self.forceLandscape ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationPortrait;

    if (@available(iOS 16.0, *)) {
        UIWindowScene *windowScene = self.view.window.windowScene;
        UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:mask];
        [windowScene requestGeometryUpdateWithPreferences:preferences errorHandler:^(NSError *error) {
            [[UIDevice currentDevice] setValue:@(orientation) forKey:@"orientation"];
            [UIViewController attemptRotationToDeviceOrientation];
        }];
    } else {
        [[UIDevice currentDevice] setValue:@(orientation) forKey:@"orientation"];
        [UIViewController attemptRotationToDeviceOrientation];
    }
}

@end
