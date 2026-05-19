#import "SystemFrontBoardSceneHost.h"
#import <objc/message.h>

@interface SystemFrontBoardSceneHost ()
@property(nonatomic, strong, nullable) NSObject *binder;
@property(nonatomic, strong, nullable) NSObject *scene;
@property(nonatomic, copy) NSString *lastFailureReason;
@end

@implementation SystemFrontBoardSceneHost

+ (instancetype)sharedHost {
    static SystemFrontBoardSceneHost *host;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        host = [SystemFrontBoardSceneHost new];
    });
    return host;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastFailureReason = @"";
    }
    return self;
}

- (BOOL)available {
    return NSClassFromString(@"UIRootWindowScenePresentationBinder") &&
        NSClassFromString(@"FBSceneManager") &&
        NSClassFromString(@"FBSMutableSceneDefinition") &&
        NSClassFromString(@"FBSSceneIdentity") &&
        NSClassFromString(@"FBSSceneClientIdentity") &&
        NSClassFromString(@"UIApplicationSceneSpecification") &&
        NSClassFromString(@"FBSMutableSceneParameters");
}

- (NSString *)diagnosticSummary {
    return [NSString stringWithFormat:@"available=%@, scene=%@, lastFailure=%@",
            self.available ? @"yes" : @"no",
            self.scene ? @"yes" : @"no",
            self.lastFailureReason.length > 0 ? self.lastFailureReason : @"none"];
}

- (BOOL)startWithWindowScene:(UIWindowScene *)windowScene {
    if (self.binder && self.scene) {
        return YES;
    }

    Class binderClass = NSClassFromString(@"UIRootWindowScenePresentationBinder");
    Class definitionClass = NSClassFromString(@"FBSMutableSceneDefinition");
    Class sceneIdentityClass = NSClassFromString(@"FBSSceneIdentity");
    Class clientIdentityClass = NSClassFromString(@"FBSSceneClientIdentity");
    Class specificationClass = NSClassFromString(@"UIApplicationSceneSpecification");
    Class parametersClass = NSClassFromString(@"FBSMutableSceneParameters");
    Class sceneManagerClass = NSClassFromString(@"FBSceneManager");

    if (!binderClass || !definitionClass || !sceneIdentityClass || !clientIdentityClass ||
        !specificationClass || !parametersClass || !sceneManagerClass) {
        self.lastFailureReason = @"FrontBoard classes missing";
        return NO;
    }

    id displayConfiguration = [windowScene valueForKeyPath:@"_effectiveSettings.displayConfiguration"];
    id allocatedBinder = ((id (*)(id, SEL))objc_msgSend)(binderClass, @selector(alloc));
    id binder = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)(
        allocatedBinder,
        NSSelectorFromString(@"initWithPriority:displayConfiguration:"),
        0,
        displayConfiguration
    );
    if (!binder) {
        self.lastFailureReason = @"Could not create presentation binder";
        return NO;
    }

    id definition = ((id (*)(id, SEL))objc_msgSend)(definitionClass, NSSelectorFromString(@"definition"));
    NSString *identifier = NSBundle.mainBundle.bundleIdentifier ?: @"com.vteen.RealtimeTranslator";
    id identity = ((id (*)(id, SEL, id))objc_msgSend)(sceneIdentityClass, NSSelectorFromString(@"identityForIdentifier:"), identifier);
    id clientIdentity = ((id (*)(id, SEL))objc_msgSend)(clientIdentityClass, NSSelectorFromString(@"localIdentity"));
    id specification = ((id (*)(id, SEL))objc_msgSend)(specificationClass, NSSelectorFromString(@"specification"));
    id parameters = ((id (*)(id, SEL, id))objc_msgSend)(parametersClass, NSSelectorFromString(@"parametersForSpecification:"), specification);
    id sceneManager = ((id (*)(id, SEL))objc_msgSend)(sceneManagerClass, NSSelectorFromString(@"sharedInstance"));

    if (!definition || !identity || !clientIdentity || !specification || !parameters || !sceneManager) {
        self.lastFailureReason = @"Could not create scene definition";
        return NO;
    }

    [definition setValue:identity forKey:@"identity"];
    [definition setValue:clientIdentity forKey:@"clientIdentity"];
    [definition setValue:specification forKey:@"specification"];

    id settings = [[windowScene valueForKey:@"_effectiveSettings"] mutableCopy];
    if (settings) {
        [settings setValue:@0 forKey:@"deactivationReasons"];
        [settings setValue:@(YES) forKey:@"foreground"];
        [settings setValue:@0 forKey:@"interruptionPolicy"];
        [parameters setValue:settings forKey:@"settings"];
    }
    [parameters setValue:[windowScene valueForKey:@"_effectiveUIClientSettings"] forKey:@"clientSettings"];

    id createdScene = ((id (*)(id, SEL, id, id))objc_msgSend)(
        sceneManager,
        NSSelectorFromString(@"createSceneWithDefinition:initialParameters:"),
        definition,
        parameters
    );
    if (!createdScene) {
        self.lastFailureReason = @"FBSceneManager createScene failed";
        return NO;
    }

    ((void (*)(id, SEL, id))objc_msgSend)(binder, NSSelectorFromString(@"addScene:"), createdScene);
    self.binder = binder;
    self.scene = createdScene;
    self.lastFailureReason = @"";
    return YES;
}

- (void)stop {
    if (self.scene) {
        Class sceneManagerClass = NSClassFromString(@"FBSceneManager");
        id sceneManager = sceneManagerClass ? ((id (*)(id, SEL))objc_msgSend)(sceneManagerClass, NSSelectorFromString(@"sharedInstance")) : nil;
        if (sceneManager) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(
                sceneManager,
                NSSelectorFromString(@"destroyScene:withTransitionContext:"),
                self.scene,
                nil
            );
        }
    }

    self.scene = nil;
    self.binder = nil;
}

@end
