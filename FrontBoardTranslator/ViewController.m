#import "DecoratedAppSceneView.h"
#import "TransifyrSubtitleView.h"
#import "ViewController.h"

@interface ViewController ()
@property(nonatomic) FBApplicationProcessLaunchTransaction *transaction;
@property(nonatomic) UIScenePresentationManager *presentationManager;
@property(nonatomic, strong) TransifyrSubtitleView *subtitleView;
@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
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

    TransifyrSubtitleView *subtitleView = [[TransifyrSubtitleView alloc] initWithFrame:CGRectZero];
    subtitleView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    self.subtitleView = subtitleView;
    [self.view addSubview:self.subtitleView];
    [self.subtitleView start];
    [self layoutSubtitleView];

    // Keep the shell visually transparent; the old drag/title handle created a dark band over SpringBoard.
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
}

@end
