#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

static NSMutableArray *events;
static NSMutableArray *notifications;
static UIScene *connected_scene;
static UISceneConnectionOptions *connection_options;
static NSUInteger scenes_seen_at_launch = NSNotFound;
static BOOL configuration_asked;
static NSString *asked_for_role;
static BOOL wrong_delegate_used;
static NSUserActivity *activity_at_connect;
static NSUserActivity *activity_restored;
static BOOL give_no_activity;
static NSString *const restoration_marker = @"space.kern0x1b.test.restoration.marker";

@interface CharonWrongSceneDelegate : UIResponder <UIWindowSceneDelegate>
@end

@implementation CharonWrongSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
    wrong_delegate_used = YES;
}

@end

@interface CharonSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
    [events addObject:@"willConnect"];
    activity_at_connect = session.stateRestorationActivity;
    connected_scene = scene;
    connection_options = options;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
}

- (NSUserActivity *)stateRestorationActivityForScene:(UIScene *)scene
{
    if (give_no_activity)
        return nil;
    NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"space.kern0x1b.test.page"];
    activity.title = @"Page 7";
    activity.userInfo = @{@"page": @7, @"name": @"seven", @"scroll": @[@1.5, @2.5]};
    return activity;
}

- (void)scene:(UIScene *)scene restoreInteractionStateWithUserActivity:(NSUserActivity *)activity
{
    activity_restored = activity;
}

- (void)sceneWillEnterForeground:(UIScene *)scene
{
    [events addObject:[NSString stringWithFormat:@"willEnterForeground:%ld", (long)scene.activationState]];
}

- (void)sceneDidBecomeActive:(UIScene *)scene
{
    [events addObject:[NSString stringWithFormat:@"didBecomeActive:%ld", (long)scene.activationState]];
}

- (void)sceneWillResignActive:(UIScene *)scene
{
    [events addObject:[NSString stringWithFormat:@"willResignActive:%ld", (long)scene.activationState]];
}

- (void)sceneDidEnterBackground:(UIScene *)scene
{
    [events addObject:[NSString stringWithFormat:@"didEnterBackground:%ld", (long)scene.activationState]];
}

@end

@interface CharonScenesDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CharonScenesDelegate

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
    configuration_asked = YES;
    asked_for_role = session.role;
    return [UISceneConfiguration configurationWithName:@"Default" sessionRole:session.role];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"scenes.log"]);
    scenes_seen_at_launch = [UIApplication sharedApplication].connectedScenes.count;
    [self performSelector:@selector(runAndReport) withObject:nil afterDelay:0];
    return YES;
}

- (void)runAndReport
{
    @try {
        [self run];
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"scenes.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)run
{
    Dl_info info;
    CHECK(dladdr((__bridge const void *)[UIScene class], &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libUIKitBackports.dylib"), "UIScene comes from the backports library");
    UIApplication *application = [UIApplication sharedApplication];
    CHECK(wait_until(^{ return (BOOL)(connected_scene != nil); }, 10), "the scene delegate is told the scene is connecting");
    CHECK(!wrong_delegate_used, "the configuration is looked up in the manifest by the name the application delegate gave");
    CHECK(configuration_asked && [asked_for_role isEqual:UIWindowSceneSessionRoleApplication], "the application delegate is asked for a configuration for the application role");
    CHECK(scenes_seen_at_launch == 1, "there is one scene when the application has finished launching");
    CHECK([connected_scene isKindOfClass:[UIWindowScene class]], "it is a window scene");
    CHECK(application.connectedScenes.count == 1 && [application.connectedScenes containsObject:connected_scene], "the connected scenes are that one");
    CHECK(application.openSessions.count == 1 && [application.openSessions containsObject:connected_scene.session], "and its session is the one open session");
    CHECK(!application.supportsMultipleScenes, "the application does not support multiple scenes");
    UISceneSession *session = connected_scene.session;
    CHECK(session.scene == connected_scene && [session.role isEqual:UIWindowSceneSessionRoleApplication] && session.persistentIdentifier.length > 0, "the session knows its scene, role and identifier");
    CHECK([session.configuration.name isEqual:@"Default"] && session.configuration.delegateClass == [CharonSceneDelegate class], "and its configuration is the named one with its delegate class");
    CHECK([connected_scene.delegate isKindOfClass:[CharonSceneDelegate class]], "the scene keeps its delegate");
    CHECK(connection_options.URLContexts.count == 0 && connection_options.userActivities.count == 0 && connection_options.shortcutItem == nil, "a plain launch has no URL, activity or shortcut");
    CHECK(wait_until(^{ return (BOOL)(connected_scene.activationState == UISceneActivationStateForegroundActive); }, 10), "the scene becomes active");
    NSArray *expected = @[@"willConnect", @"willEnterForeground:1", @"didBecomeActive:0"];
    CHECK_EQUAL(events, expected, "the delegate hears of it in the order willConnect, willEnterForeground, didBecomeActive");
    UIWindowScene *scene = (UIWindowScene *)connected_scene;
    UIWindow *window = ((CharonSceneDelegate *)scene.delegate).window;
    CHECK(window.windowScene == scene && window.isKeyWindow, "a window made with the scene belongs to it and is the key window");
    CHECK(scene.screen == [UIScreen mainScreen] && [scene.windows containsObject:window] && scene.sizeRestrictions == nil && scene.fullScreen, "the scene has the screen, the windows, no size restrictions and is full screen");
    CHECK(scene.statusBarManager != nil && scene.statusBarManager.statusBarHidden == application.statusBarHidden && scene.statusBarManager.statusBarStyle == application.statusBarStyle, "its status bar manager reads the application's");
    CHECK(scene.interfaceOrientation == application.statusBarOrientation, "its interface orientation is the application's");
    CGRect bounds = scene.coordinateSpace.bounds;
    CHECK(bounds.size.width > 0 && bounds.size.height > 0, "its coordinate space has a size");
    CHECK([scene.title isEqual:@""] && [scene.activationConditions.canActivateForTargetContentIdentifierPredicate evaluateWithObject:@"anything"], "a scene starts with no title and can activate for anything");
    __block NSError *refused = nil;
    __block BOOL answered = NO;
    UISceneSession *foreign = nil;
    [application requestSceneSessionActivation:foreign userActivity:nil options:nil errorHandler:^(NSError *error) {
        refused = error;
        answered = YES;
    }];
    CHECK(wait_until(^{ return answered; }, 5) && refused.code == 0 && [refused.domain isEqual:@"UISceneErrorDomain"], "a second scene is refused as multiple scenes not supported");
    answered = NO;
    [application requestSceneSessionDestruction:session options:nil errorHandler:^(NSError *error) {
        refused = error;
        answered = YES;
    }];
    CHECK(wait_until(^{ return answered; }, 5) && refused.code == 1, "destroying the one scene is denied");
    __block BOOL opened = YES;
    answered = NO;
    UISceneOpenExternalURLOptions *only = [[UISceneOpenExternalURLOptions alloc] init];
    only.universalLinksOnly = YES;
    [scene openURL:[NSURL URLWithString:@"http://example.com/"] options:only completionHandler:^(BOOL success) {
        opened = success;
        answered = YES;
    }];
    CHECK(wait_until(^{ return answered; }, 5) && !opened, "opening a URL for universal links only fails, iOS 6 has none");
    NSUInteger before = events.count;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:UIApplicationWillResignActiveNotification object:application];
    CHECK(connected_scene.activationState == UISceneActivationStateForegroundInactive && [events.lastObject isEqual:@"willResignActive:1"], "resigning active makes the scene foreground inactive");
    [center postNotificationName:UIApplicationDidEnterBackgroundNotification object:application];
    CHECK(connected_scene.activationState == UISceneActivationStateBackground && [events.lastObject isEqual:@"didEnterBackground:2"], "entering the background makes it background");
    [center postNotificationName:UIApplicationWillEnterForegroundNotification object:application];
    CHECK(connected_scene.activationState == UISceneActivationStateForegroundInactive && [events.lastObject isEqual:@"willEnterForeground:1"], "coming back makes it foreground inactive");
    [center postNotificationName:UIApplicationDidBecomeActiveNotification object:application];
    CHECK(connected_scene.activationState == UISceneActivationStateForegroundActive && [events.lastObject isEqual:@"didBecomeActive:0"], "becoming active makes it foreground active");
    CHECK(events.count == before + 4, "each step is one delegate call");
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *note in notifications)
        [names addObject:note[@"name"]];
    CHECK([names containsObject:UISceneWillConnectNotification] && [names containsObject:UISceneWillEnterForegroundNotification] && [names containsObject:UISceneDidActivateNotification]
              && [names containsObject:UISceneWillDeactivateNotification] && [names containsObject:UISceneDidEnterBackgroundNotification],
          "the scene notifications are posted with the steps");
    BOOL sceneObject = YES;
    for (NSDictionary *note in notifications)
        sceneObject = sceneObject && note[@"object"] == connected_scene;
    CHECK(sceneObject, "each has the scene as its object");

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL secondLaunch = [defaults boolForKey:restoration_marker];
    NSString *keptKey = nil;
    for (NSString *key in [[defaults dictionaryRepresentation] allKeys])
        if ([key hasPrefix:@"space.kern0x1b.charon.UISceneStateRestoration."])
            keptKey = key;
    if (!secondLaunch) {
        CHECK(activity_at_connect == nil && activity_restored == nil, "a first launch has nothing to restore");
        CHECK(keptKey != nil && [defaults dataForKey:keptKey].length > 0, "entering the background keeps what the scene delegate answered");
        [defaults setBool:YES forKey:restoration_marker];
        [defaults synchronize];
    } else {
        CHECK(activity_at_connect != nil && [activity_at_connect.activityType isEqual:@"space.kern0x1b.test.page"] && [activity_at_connect.title isEqual:@"Page 7"]
                  && [activity_at_connect.userInfo[@"page"] isEqual:@7] && [activity_at_connect.userInfo[@"name"] isEqual:@"seven"]
                  && [activity_at_connect.userInfo[@"scroll"] isEqual:(@[@1.5, @2.5])],
              "the next launch has the kept activity in the session before the scene connects");
        CHECK(activity_restored == activity_at_connect || [activity_restored.userInfo isEqual:activity_at_connect.userInfo], "and the delegate is asked to restore it");
        give_no_activity = YES;
        [center postNotificationName:UIApplicationWillResignActiveNotification object:application];
        [center postNotificationName:UIApplicationDidEnterBackgroundNotification object:application];
        keptKey = nil;
        for (NSString *key in [[defaults dictionaryRepresentation] allKeys])
            if ([key hasPrefix:@"space.kern0x1b.charon.UISceneStateRestoration."])
                keptKey = key;
        CHECK(keptKey == nil, "an answer of nil removes what was kept");
        [defaults removeObjectForKey:restoration_marker];
        [defaults synchronize];
    }
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        events = [NSMutableArray array];
        notifications = [NSMutableArray array];
        for (NSString *name in @[UISceneWillConnectNotification, UISceneDidActivateNotification, UISceneWillDeactivateNotification, UISceneWillEnterForegroundNotification, UISceneDidEnterBackgroundNotification])
            [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
                [notifications addObject:@{@"name": note.name, @"object": note.object ?: [NSNull null]}];
            }];
        return UIApplicationMain(argc, argv, nil, @"CharonScenesDelegate");
    }
}
