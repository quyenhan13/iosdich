#import "DecoratedAppSceneView.h"
#import "TransifyrSubtitleView.h"
#import "ViewController.h"

@interface ViewController ()
@property(nonatomic) FBApplicationProcessLaunchTransaction *transaction;
@property(nonatomic) UIScenePresentationManager *presentationManager;
@property(nonatomic, strong) TransifyrSubtitleView *subtitleView;
@property(nonatomic, strong) UIButton *rotateButton;
@property(nonatomic, assign) NSInteger orientationMode;
@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (self.orientationMode == 1) {
        return UIInterfaceOrientationMaskLandscape;
    }
    if (self.orientationMode == 2) {
        return UIInterfaceOrientationMaskPortrait;
    }
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.title = nil;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutSubtitleView];
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.opaque = NO;
    self.title = nil;
    self.orientationMode = 0;

    TransifyrSubtitleView *subtitleView = [[TransifyrSubtitleView alloc] initWithFrame:CGRectZero];
    subtitleView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    self.subtitleView = subtitleView;
    [self.view addSubview:self.subtitleView];
    [self.subtitleView start];
    [self configureRotateButton];
    [self layoutSubtitleView];

    // Keep the shell visually transparent; the old drag/title handle created a dark band over SpringBoard.
}

- (void)configureRotateButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = UIColor.whiteColor;
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.34];
    button.layer.cornerRadius = 18;
    button.layer.masksToBounds = YES;
    [button setTitle:@"Auto" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(cycleOrientationMode) forControlEvents:UIControlEventTouchUpInside];
    self.rotateButton = button;
    [self.view addSubview:button];
}

- (void)layoutSubtitleView {
    if (!self.subtitleView) {
        return;
    }

    CGRect bounds = self.view.bounds;
    if (CGRectIsEmpty(bounds)) {
        bounds = UIScreen.mainScreen.bounds;
    }

    BOOL landscape = bounds.size.width > bounds.size.height;
    CGFloat horizontalInset = landscape ? 80 : 16;
    CGFloat width = MIN(bounds.size.width - horizontalInset * 2, landscape ? 720 : 520);
    CGFloat height = landscape ? 78 : 92;
    CGFloat bottomInset = self.view.safeAreaInsets.bottom + (landscape ? 34 : 120);
    CGFloat x = (bounds.size.width - width) / 2;
    CGFloat y = MAX(self.view.safeAreaInsets.top + 12, bounds.size.height - bottomInset - height);

    self.subtitleView.frame = CGRectMake(x, y, width, height);

    CGFloat buttonWidth = 76;
    CGFloat buttonHeight = 36;
    self.rotateButton.frame = CGRectMake(bounds.size.width - buttonWidth - 12, self.view.safeAreaInsets.top + 12, buttonWidth, buttonHeight);
}

- (void)cycleOrientationMode {
    self.orientationMode = (self.orientationMode + 1) % 3;
    if (self.orientationMode == 0) {
        [self.rotateButton setTitle:@"Auto" forState:UIControlStateNormal];
        [self setNeedsUpdateOfSupportedInterfaceOrientations];
        if (@available(iOS 16.0, *)) {
            UIWindowScene *windowScene = self.view.window.windowScene;
            UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskAll];
            [windowScene requestGeometryUpdateWithPreferences:preferences errorHandler:nil];
        }
        [UIViewController attemptRotationToDeviceOrientation];
    } else if (self.orientationMode == 1) {
        [self.rotateButton setTitle:@"Ngang" forState:UIControlStateNormal];
        [self forceOrientation:UIInterfaceOrientationLandscapeRight];
    } else {
        [self.rotateButton setTitle:@"Doc" forState:UIControlStateNormal];
        [self forceOrientation:UIInterfaceOrientationPortrait];
    }
    [self.view setNeedsLayout];
}

- (void)forceOrientation:(UIInterfaceOrientation)orientation {
    [self setNeedsUpdateOfSupportedInterfaceOrientations];
    UIInterfaceOrientationMask mask = UIInterfaceOrientationMaskPortrait;
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        mask = UIInterfaceOrientationMaskLandscapeRight;
    }

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
