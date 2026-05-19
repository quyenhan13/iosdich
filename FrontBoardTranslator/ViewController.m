#import "DecoratedAppSceneView.h"
#import "TransifyrSubtitleView.h"
#import "ViewController.h"

@interface ViewController ()
@property(nonatomic) FBApplicationProcessLaunchTransaction *transaction;
@property(nonatomic) UIScenePresentationManager *presentationManager;
@end

@implementation ViewController

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = UIColor.clearColor;
    self.title = @"Transifyr";

    CGFloat width = MIN(UIScreen.mainScreen.bounds.size.width - 32, 520);
    CGFloat height = 92;
    CGRect frame = CGRectMake(0, 0, width, height);
    TransifyrSubtitleView *subtitleView = [[TransifyrSubtitleView alloc] initWithFrame:frame];
    subtitleView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds) - 120);
    subtitleView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:subtitleView];
    [subtitleView start];

    UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 400, 44)];
    navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:@"Transifyr"];
    navigationBar.items = @[navigationItem];

    DecoratedFloatingView *handleView = [[DecoratedFloatingView alloc] initWithFrame:CGRectMake(0, 0, 400, 96) navigationBar:navigationBar];
    handleView.center = CGPointMake(self.view.center.x, 80);
    handleView.alpha = 0.35;
    [self.view addSubview:handleView];
}

@end
