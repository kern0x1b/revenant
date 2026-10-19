#import "smallapis2-cases.h"

@interface AppearanceLeaf : UIView
@property (nonatomic, strong) UIColor *leafColor UI_APPEARANCE_SELECTOR;
@end

@implementation AppearanceLeaf
@end

@interface AppearanceBox : UIView <UIAppearanceContainer>
@end

@implementation AppearanceBox
@end

@interface AppearanceInner : UIView <UIAppearanceContainer>
@end

@implementation AppearanceInner
@end

static NSString *color(UIColor *c)
{
    if (!c)
        return @"none";
    const CGFloat *components = CGColorGetComponents(c.CGColor);
    size_t count = CGColorGetNumberOfComponents(c.CGColor);
    return count >= 3 ? [NSString stringWithFormat:@"%.1f %.1f %.1f", components[0], components[1], components[2]] : [NSString stringWithFormat:@"%.1f %.1f %.1f", components[0], components[0], components[0]];
}

void smallapis2_run(UIWindow *window, SmallApis2Recorder record)
{
    UIViewController *root = [[UIViewController alloc] init];
    window.rootViewController = root;
    [[AppearanceLeaf appearanceWhenContainedInInstancesOfClasses:@[[AppearanceBox class]]] setLeafColor:[UIColor redColor]];
    [[AppearanceLeaf appearanceWhenContainedInInstancesOfClasses:@[[AppearanceInner class], [AppearanceBox class]]] setLeafColor:[UIColor blueColor]];
    AppearanceBox *box = [[AppearanceBox alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    AppearanceLeaf *inside = [[AppearanceLeaf alloc] init];
    [box addSubview:inside];
    AppearanceLeaf *outside = [[AppearanceLeaf alloc] init];
    AppearanceBox *outer = [[AppearanceBox alloc] initWithFrame:CGRectMake(0, 100, 100, 100)];
    AppearanceInner *inner = [[AppearanceInner alloc] init];
    AppearanceLeaf *deep = [[AppearanceLeaf alloc] init];
    [outer addSubview:inner];
    [inner addSubview:deep];
    [root.view addSubview:box];
    [root.view addSubview:outside];
    [root.view addSubview:outer];
    [window layoutIfNeeded];
    for (int index = 0; index < 5; index++)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    record(@"inside a container", color(inside.leafColor));
    record(@"outside", color(outside.leafColor));
    record(@"two containers", color(deep.leafColor));
    id proxy = [AppearanceLeaf appearanceWhenContainedInInstancesOfClasses:@[]];
    record(@"none is the plain appearance", [NSString stringWithFormat:@"%d", proxy == [AppearanceLeaf appearance]]);
    record(@"a proxy for a bar item", [NSString stringWithFormat:@"%d", [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UINavigationBar class]]] != nil]);
    UIApplication *application = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier named = [application beginBackgroundTaskWithName:@"a name" expirationHandler:^{}];
    UIBackgroundTaskIdentifier unnamed = [application beginBackgroundTaskWithName:nil expirationHandler:nil];
    record(@"tasks", [NSString stringWithFormat:@"%d %d %d", named != UIBackgroundTaskInvalid, unnamed != UIBackgroundTaskInvalid, named != unnamed]);
    [application endBackgroundTask:named];
    [application endBackgroundTask:unnamed];
    NSNetService *service = [[NSNetService alloc] initWithDomain:@"local." type:@"_charon._tcp." name:@"charon" port:9];
    NSNetServiceBrowser *browser = [[NSNetServiceBrowser alloc] init];
    record(@"peer to peer defaults", [NSString stringWithFormat:@"%d %d", service.includesPeerToPeer, browser.includesPeerToPeer]);
    service.includesPeerToPeer = YES;
    browser.includesPeerToPeer = YES;
    record(@"peer to peer kept", [NSString stringWithFormat:@"%d %d", service.includesPeerToPeer, browser.includesPeerToPeer]);
}
