#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"
#import "gesture.h"

static NSString *const results_folder = @"/private/var/backports";

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

static UIColor *pixel_of(UIImage *image)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    unsigned char data[4] = {0};
    CGContextRef context = CGBitmapContextCreate(data, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), image.CGImage);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return [UIColor colorWithRed:data[0] / 255.0 green:data[1] / 255.0 blue:data[2] / 255.0 alpha:data[3] / 255.0];
}

static BOOL is_colour(UIImage *image, CGFloat red, CGFloat green, CGFloat blue)
{
    if (!image)
        return NO;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [pixel_of(image) getRed:&r green:&g blue:&b alpha:&a];
    return fabs(r - red) < 0.05 && fabs(g - green) < 0.05 && fabs(b - blue) < 0.05 && a > 0.95;
}

static UINavigationBarAppearance *navigation_appearance(UIColor *colour)
{
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = colour;
    return appearance;
}

static UITabBarAppearance *tab_appearance(UIColor *colour)
{
    UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = colour;
    return appearance;
}

@interface CharonRowsController : UITableViewController
@end

@implementation CharonRowsController

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 100;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];
    cell.textLabel.text = [NSString stringWithFormat:@"row %ld", (long)indexPath.row];
    return cell;
}

@end

@interface CharonBarsDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonBarsDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"barsapp.log"]);
    UIViewController *root = [[UIViewController alloc] init];
    root.title = @"Bars";
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndReport) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)runAndReport
{
    @try {
        [self run];
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    @try {
        [self runScrolling];
    } @catch (NSException *exception) {
        charon_check(NO, "the scrolling checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    if (gesture_ready() && [UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        [self performSelector:@selector(runDragAndFinish) withObject:nil afterDelay:1.0];
    else
        [self finish];
}

- (void)finish
{
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"barsapp.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (UINavigationBar *)scrollingBar
{
    UITabBarController *tabs = (UITabBarController *)self.window.rootViewController;
    return [(UINavigationController *)tabs.viewControllers[0] navigationBar];
}

- (UITableView *)scrollingTable
{
    UINavigationController *navigation = (UINavigationController *)[(UITabBarController *)self.window.rootViewController viewControllers][0];
    return [(UITableViewController *)navigation.topViewController tableView];
}

- (void)runDragAndFinish
{
    UINavigationBar *bar = [self scrollingBar];
    UITableView *table = [self scrollingTable];
    __block BOOL scrolledAway = NO;
    gesture_drag(^{ return CGPointMake(160, 380); }, ^{ return CGPointMake(160, 120); }, 12, 0.3);
    gesture_step(0.2, ^{
        scrolledAway = table.contentOffset.y > 40;
        CHECK(scrolledAway, "a finger drag scrolls the table");
        CHECK(is_colour([bar backgroundImageForBarMetrics:UIBarMetricsDefault], 1, 0, 0) || table.decelerating, "and the bar takes the standard appearance while it is scrolled away");
    });
    gesture_step(2.0, ^{ });
    gesture_step(0.1, ^{ CHECK(is_colour([bar backgroundImageForBarMetrics:UIBarMetricsDefault], 1, 0, 0), "the bar keeps the standard appearance after the drag settles"); });
    gesture_drag(^{ return CGPointMake(160, 120); }, ^{ return CGPointMake(160, 460); }, 14, 0.3);
    gesture_step(0.1, ^{ });
    gesture_step(2.5, ^{ });
    gesture_step(0.1, ^{
        if (table.contentOffset.y > 0.5)
            [table setContentOffset:CGPointMake(0, -table.contentInset.top) animated:NO];
    });
    gesture_step(0.5, ^{ CHECK(is_colour([bar backgroundImageForBarMetrics:UIBarMetricsDefault], 0, 0, 1), "a finger drag back to the top returns the scroll edge appearance"); });
    gesture_run(^{ [self finish]; });
}

- (void)runScrolling
{
    UITabBarController *tabs = [[UITabBarController alloc] init];
    CharonRowsController *first = [[CharonRowsController alloc] initWithStyle:UITableViewStylePlain];
    first.title = @"first";
    UINavigationController *firstNavigation = [[UINavigationController alloc] initWithRootViewController:first];
    firstNavigation.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"first" image:nil tag:0];
    CharonRowsController *second = [[CharonRowsController alloc] initWithStyle:UITableViewStylePlain];
    second.title = @"second";
    second.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"second" image:nil tag:1];
    tabs.viewControllers = @[firstNavigation, second];
    self.window.rootViewController = tabs;
    UINavigationBar *bar = firstNavigation.navigationBar;
    UITableView *table = first.tableView;

    UIColor *red = [UIColor colorWithRed:1 green:0 blue:0 alpha:1], *blue = [UIColor colorWithRed:0 green:0 blue:1 alpha:1], *green = [UIColor colorWithRed:0 green:1 blue:0 alpha:1];
    UIColor *purple = [UIColor colorWithRed:0.5 green:0 blue:0.5 alpha:1], *orange = [UIColor colorWithRed:1 green:0.5 blue:0 alpha:1], *yellow = [UIColor colorWithRed:1 green:1 blue:0 alpha:1];
    bar.standardAppearance = navigation_appearance(red);
    bar.scrollEdgeAppearance = navigation_appearance(blue);
    UIImage *(^background)(void) = ^{ return [bar backgroundImageForBarMetrics:UIBarMetricsDefault]; };
    CHECK(wait_until(^BOOL { return is_colour(background(), 0, 0, 1); }, 3), "at the top of the table the bar takes the scroll edge appearance");
    [table setContentOffset:CGPointMake(0, 300) animated:NO];
    CHECK(wait_until(^BOOL { return is_colour(background(), 1, 0, 0); }, 3), "scrolled away from the top it takes the standard appearance");
    [table setContentOffset:CGPointMake(0, -table.contentInset.top) animated:NO];
    CHECK(wait_until(^BOOL { return is_colour(background(), 0, 0, 1); }, 3), "back at the top it takes the scroll edge appearance again");

    UINavigationBarAppearance *compactEdge = navigation_appearance(green);
    bar.compactScrollEdgeAppearance = compactEdge;
    UIImage *landscape = [bar backgroundImageForBarMetrics:UIBarMetricsLandscapePhone];
    CHECK(is_colour(landscape, 0, 1, 0), "the compact scroll edge appearance goes to the landscape metrics at the top");
    [table setContentOffset:CGPointMake(0, 300) animated:NO];
    CHECK(wait_until(^BOOL { return ![bar backgroundImageForBarMetrics:UIBarMetricsLandscapePhone] || is_colour([bar backgroundImageForBarMetrics:UIBarMetricsLandscapePhone], 1, 0, 0) || !is_colour([bar backgroundImageForBarMetrics:UIBarMetricsLandscapePhone], 0, 1, 0); }, 3),
          "scrolled away the landscape metrics leave the compact scroll edge appearance");
    [table setContentOffset:CGPointMake(0, -table.contentInset.top) animated:NO];
    bar.compactScrollEdgeAppearance = nil;
    wait_until(^BOOL { return is_colour(background(), 0, 0, 1); }, 3);

    UIViewController *plain = [[UIViewController alloc] init];
    plain.title = @"plain";
    plain.navigationItem.scrollEdgeAppearance = navigation_appearance(green);
    [firstNavigation pushViewController:plain animated:NO];
    CHECK(wait_until(^BOOL { return is_colour(background(), 0, 1, 0); }, 3), "a pushed item's own scroll edge appearance is the bar's while it is on top");
    [firstNavigation popViewControllerAnimated:NO];
    CHECK(wait_until(^BOOL { return is_colour(background(), 0, 0, 1); }, 3), "popping it returns the bar's own");

    CharonRowsController *pushed = [[CharonRowsController alloc] initWithStyle:UITableViewStylePlain];
    pushed.title = @"pushed";
    pushed.navigationItem.standardAppearance = navigation_appearance(purple);
    [firstNavigation pushViewController:pushed animated:YES];
    CHECK(wait_until(^BOOL { return is_colour(background(), 0, 0, 1); }, 3), "at the top of a pushed table the bar's scroll edge appearance comes before the item's standard one");
    [pushed.tableView setContentOffset:CGPointMake(0, 300) animated:NO];
    CHECK(wait_until(^BOOL { return is_colour(background(), 0.5, 0, 0.5); }, 3), "scrolled away, the item's standard appearance is the bar's");
    pushed.navigationItem.standardAppearance = navigation_appearance(orange);
    CHECK(wait_until(^BOOL { return is_colour(background(), 1, 0.5, 0); }, 3), "replacing the item's appearance while it is on top applies it");
    [firstNavigation popViewControllerAnimated:YES];
    CHECK(wait_until(^BOOL { return is_colour(background(), 0, 0, 1); }, 3), "popping it with an animation returns the bar to its own");
    [table setContentOffset:CGPointMake(0, 300) animated:NO];
    CHECK(wait_until(^BOOL { return is_colour(background(), 1, 0, 0); }, 3), "and the table underneath is watched again");
    [table setContentOffset:CGPointMake(0, -table.contentInset.top) animated:NO];

    UITabBar *tabBar = tabs.tabBar;
    tabBar.standardAppearance = tab_appearance(orange);
    tabBar.scrollEdgeAppearance = tab_appearance(yellow);
    CHECK(wait_until(^BOOL { return is_colour(tabBar.backgroundImage, 1, 0.5, 0); }, 3), "a tab bar takes its standard appearance while the table is not at its bottom");
    [table setContentOffset:CGPointMake(0, table.contentSize.height - table.bounds.size.height + table.contentInset.bottom) animated:NO];
    CHECK(wait_until(^BOOL { return is_colour(tabBar.backgroundImage, 1, 1, 0); }, 3), "and its scroll edge appearance at the bottom");
    [table setContentOffset:CGPointMake(0, 0) animated:NO];
    wait_until(^BOOL { return is_colour(tabBar.backgroundImage, 1, 0.5, 0); }, 3);
    second.tabBarItem.standardAppearance = tab_appearance(purple);
    tabs.selectedIndex = 1;
    CHECK(wait_until(^BOOL { return is_colour(tabBar.backgroundImage, 0.5, 0, 0.5); }, 3), "the appearance of the selected tab item is the tab bar's");
    tabs.selectedIndex = 0;
    CHECK(wait_until(^BOOL { return is_colour(tabBar.backgroundImage, 1, 0.5, 0); }, 3), "selecting the other tab returns the tab bar to its own");
    tabs.selectedIndex = 1;
    wait_until(^BOOL { return is_colour(tabBar.backgroundImage, 0.5, 0, 0.5); }, 3);
    tabs.selectedIndex = 0;
}

- (void)run
{
    Dl_info info;
    CHECK(dladdr((__bridge const void *)[UINavigationBarAppearance class], &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libUIKitBackports.dylib"), "UINavigationBarAppearance comes from the backports library");
    UINavigationController *navigation = (UINavigationController *)self.window.rootViewController;
    UINavigationBar *bar = navigation.navigationBar;
    CHECK(bar.standardAppearance != nil && bar.compactAppearance == nil, "a navigation bar has a standard appearance and no compact one at first");

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor redColor];
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor greenColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:20]};
    bar.standardAppearance = appearance;
    UIImage *background = [bar backgroundImageForBarMetrics:UIBarMetricsDefault];
    CHECK(background != nil, "a background colour becomes a background image of the bar");
    UIColor *seen = pixel_of(background);
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [seen getRed:&red green:&green blue:&blue alpha:&alpha];
    CHECK(red > 0.95 && green < 0.05 && blue < 0.05 && alpha > 0.95, "of that colour");
    NSDictionary *title = bar.titleTextAttributes;
    CHECK([title[UITextAttributeTextColor] isEqual:[UIColor greenColor]] && [title[UITextAttributeFont] isKindOfClass:[UIFont class]], "the title attributes reach the bar, translated for iOS 6");

    UINavigationBarAppearance *compact = [[UINavigationBarAppearance alloc] init];
    [compact configureWithOpaqueBackground];
    compact.backgroundColor = [UIColor blueColor];
    bar.compactAppearance = compact;
    UIImage *landscape = [bar backgroundImageForBarMetrics:UIBarMetricsLandscapePhone];
    UIColor *blueSeen = landscape ? pixel_of(landscape) : nil;
    [blueSeen getRed:&red green:&green blue:&blue alpha:&alpha];
    CHECK(landscape != nil && blue > 0.95 && red < 0.05, "the compact appearance goes to the landscape metrics");
    UIImage *again = [bar backgroundImageForBarMetrics:UIBarMetricsDefault];
    CHECK(again != nil, "and leaves the default metrics as they were");

    UINavigationBarAppearance *changed = bar.standardAppearance;
    changed.backgroundColor = [UIColor yellowColor];
    CHECK(wait_until(^BOOL {
        CGFloat r = 0, g = 0, b = 0, a = 0;
        [pixel_of([bar backgroundImageForBarMetrics:UIBarMetricsDefault]) getRed:&r green:&g blue:&b alpha:&a];
        return r > 0.95 && g > 0.95 && b < 0.05;
    }, 5), "a change to the appearance the bar keeps is applied on a later turn");

    bar.standardAppearance = nil;
    CHECK(bar.standardAppearance != nil, "setting nil brings the default back");

    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    [self.window.rootViewController.view addSubview:toolbar];
    UIToolbarAppearance *toolbarAppearance = [[UIToolbarAppearance alloc] init];
    [toolbarAppearance configureWithOpaqueBackground];
    toolbarAppearance.backgroundColor = [UIColor purpleColor];
    toolbar.standardAppearance = toolbarAppearance;
    UIImage *toolbarImage = [toolbar backgroundImageForToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    CHECK(toolbarImage != nil, "a toolbar's background colour becomes its background image");

    UITabBar *tabBar = [[UITabBar alloc] initWithFrame:CGRectMake(0, 100, 320, 49)];
    [self.window.rootViewController.view addSubview:tabBar];
    UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
    [tabAppearance configureWithOpaqueBackground];
    tabAppearance.backgroundColor = [UIColor orangeColor];
    tabAppearance.selectionIndicatorImage = [UIImage imageNamed:@"missing"];
    tabBar.standardAppearance = tabAppearance;
    CHECK(tabBar.backgroundImage != nil, "a tab bar's background colour becomes its background image");
    CHECK(![tabBar respondsToSelector:NSSelectorFromString(@"compactAppearance")], "a tab bar has no compact appearance");
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonBarsDelegate");
    }
}
