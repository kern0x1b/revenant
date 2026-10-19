#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"
#import "searchcontroller-cases.h"
#import "searchcontroller-expectations.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const double step_timeout_seconds = 45;

static NSString *tolerance(NSString *name)
{
    static NSDictionary *reasons;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        reasons = @{
            @"cancel.button": @"the host draws no cancel button, since a Mac has none",
            @"cancel.log": @"the host has no cancel button, so its search is ended by setting active, which the application's delegate does not hear",
            @"cancel.sync": @"the host has no cancel button, so its search is ended by setting active, which the application's delegate does not hear",
            @"cancel.state": @"the height of a search bar differs between releases",
            @"inactive.noop": @"the host updates the results a second time after a dismissal has finished",
            @"new.bar": @"the port's search bar is a subclass of UISearchBar",
            @"new.state": @"the defaults for the background and the navigation bar are those of a phone and a pad, the host's those of a Mac",
            @"present.parent": @"the host presents the search controller modally over its context, the port puts it over the view of the presenting controller",
            @"present.state": @"the host keeps the navigation bar and draws no cancel button, which a Mac does",
        };
    });
    return reasons[name];
}
static NSString *const results_folder = @"/private/var/backports";

typedef void (^Step)(void (^done)(void));

static void after(double seconds, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

static BOOL shown(UIView *view)
{
    if (!view.window)
        return NO;
    for (UIView *current = view; current; current = current.superview) {
        if (current.hidden || current.alpha < 0.01)
            return NO;
    }
    return YES;
}

@interface SearchRecorder : NSObject <UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate>
@property (nonatomic, strong) NSMutableArray *log;
@property (nonatomic, weak) UIViewController *modalHost;
@property (nonatomic) BOOL presentsItself;
@end

@implementation SearchRecorder

- (instancetype)init
{
    if ((self = [super init]))
        _log = [NSMutableArray array];
    return self;
}

- (void)willPresentSearchController:(UISearchController *)controller
{
    [self.log addObject:@"willPresent"];
}

- (void)didPresentSearchController:(UISearchController *)controller
{
    [self.log addObject:@"didPresent"];
}

- (void)willDismissSearchController:(UISearchController *)controller
{
    [self.log addObject:[NSString stringWithFormat:@"willDismiss active=%d", controller.active]];
}

- (void)didDismissSearchController:(UISearchController *)controller
{
    [self.log addObject:[NSString stringWithFormat:@"didDismiss active=%d", controller.active]];
}

- (void)presentSearchController:(UISearchController *)controller
{
    [self.log addObject:@"presentSearchController"];
    [self.modalHost presentViewController:controller animated:NO completion:nil];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(presentSearchController:))
        return self.presentsItself;
    return [super respondsToSelector:selector];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)controller
{
    [self.log addObject:[NSString stringWithFormat:@"update text=%@", controller.searchBar.text ?: @"<nil>"]];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self.log addObject:[NSString stringWithFormat:@"app textDidChange %@", searchText]];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self.log addObject:@"app cancel"];
}

@end

@interface SearchTestDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigation;
@property (nonatomic, strong) UITableViewController *table;
@property (nonatomic, strong) UILabel *status;
@end

@implementation SearchTestDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"searchcontroller.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"searchcontroller.log"]);
    self.table = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    self.table.title = @"Search";
    self.navigation = [[UINavigationController alloc] initWithRootViewController:self.table];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = self.navigation;
    [self.window makeKeyAndVisible];
    NSArray *steps = [self steps];
    after(1, ^{
        [self run:steps index:0];
    });
    return YES;
}

- (void)run:(NSArray *)steps index:(NSUInteger)index
{
    if (index == steps.count) {
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        after(1, ^{
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"searchcontroller.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
        return;
    }
    printf("step %lu\n", (unsigned long)index + 1);
    __block BOOL finished = NO;
    void (^done)(void) = ^{
        if (finished)
            return;
        finished = YES;
        after(1, ^{
            [self run:steps index:index + 1];
        });
    };
    after(step_timeout_seconds, ^{
        if (!finished) {
            charon_check(NO, "step finishes in time", [NSString stringWithFormat:@"step %lu timed out", (unsigned long)index + 1]);
            done();
        }
    });
    Step step = [steps objectAtIndex:index];
    step(done);
}

- (NSArray *)steps
{
    UITableViewController *table = self.table;
    UINavigationController *navigation = self.navigation;
    UIViewController *results = [[UIViewController alloc] init];
    results.view.backgroundColor = [UIColor whiteColor];
    UISearchController *controller = [[UISearchController alloc] initWithSearchResultsController:results];
    SearchRecorder *recorder = [[SearchRecorder alloc] init];
    UISearchBar *bar = controller.searchBar;
    table.definesPresentationContext = YES;
    return @[
        [^(void (^done)(void)) {
            CHECK([@(class_getImageName([UISearchController class])) hasSuffix:@"libUIKitBackports.dylib"], "UISearchController comes from the backports library");
            CHECK(controller.searchResultsController == results, "the results controller is the one given");
            CHECK([bar isKindOfClass:[UISearchBar class]] && bar.placeholder.length > 0, "the search bar is a UISearchBar with a placeholder");
            CHECK(!controller.active && controller.searchResultsUpdater == nil && controller.delegate == nil, "a new controller is inactive, with no updater and no delegate");
            CHECK(controller.dimsBackgroundDuringPresentation && controller.obscuresBackgroundDuringPresentation && controller.hidesNavigationBarDuringPresentation, "the background is dimmed and the navigation bar hidden by default");
            controller.dimsBackgroundDuringPresentation = NO;
            CHECK(!controller.obscuresBackgroundDuringPresentation, "the two names of the dimming flag are one flag");
            controller.dimsBackgroundDuringPresentation = YES;
            CHECK(bar.delegate == nil, "the search bar has no delegate of the application at first");
            bar.frame = CGRectMake(0, 0, table.tableView.bounds.size.width, 44);
            table.tableView.tableHeaderView = bar;
            controller.delegate = recorder;
            controller.searchResultsUpdater = recorder;
            done();
        } copy],
        [^(void (^done)(void)) {
            [recorder.log removeAllObjects];
            CGRect before = bar.frame;
            controller.active = YES;
            CHECK(controller.active, "setting active makes the controller active");
            CHECK_EQUAL(recorder.log, (@[@"willPresent", @"update text="]), "presenting tells the delegate it will present and updates the results once");
            after(1, ^{
                CHECK_EQUAL(recorder.log, (@[@"willPresent", @"update text=", @"didPresent"]), "the delegate hears of the presentation once it is done");
                CHECK(shown(controller.view) && controller.view.window == navigation.view.window, "the search view is on screen");
                CHECK(bar.superview != table.tableView && shown(bar), "the search bar leaves the table header and stays visible");
                CHECK(navigation.navigationBarHidden, "the navigation bar is hidden");
                CHECK(!shown(results.view), "the results are hidden while the search text is empty");
                CHECK(bar.showsCancelButton, "the cancel button shows");
                CHECK(controller.presentedViewController == nil, "the search view is not a modal presentation of a controller");
                printf("info host %s nav hidden %d table nav %s bar hidden %d\n", [[[controller valueForKey:@"_host"] description] UTF8String], navigation.navigationBarHidden, [[table.navigationController description] UTF8String], navigation.navigationBar.hidden);
                (void)before;
                done();
            });
        } copy],
        [^(void (^done)(void)) {
            [recorder.log removeAllObjects];
            bar.text = @"ab";
            [(id<UISearchBarDelegate>)controller searchBar:bar textDidChange:@"ab"];
            CHECK_EQUAL(recorder.log, (@[@"update text=ab"]), "a change of text updates the results");
            CHECK(shown(results.view), "the results show once there is text");
            bar.delegate = recorder;
            CHECK(bar.delegate == recorder, "the application's delegate of the search bar is the one set");
            [recorder.log removeAllObjects];
            bar.text = @"abc";
            [(id<UISearchBarDelegate>)controller searchBar:bar textDidChange:@"abc"];
            CHECK_EQUAL(recorder.log, (@[@"app textDidChange abc", @"update text=abc"]), "the application's delegate hears the change before the results are updated");
            [recorder.log removeAllObjects];
            bar.text = @"";
            [(id<UISearchBarDelegate>)controller searchBar:bar textDidChange:@""];
            CHECK(!shown(results.view), "the results hide again when the text is emptied");
            CHECK_EQUAL(recorder.log, (@[@"app textDidChange ", @"update text="]), "an emptied text still updates the results");
            done();
        } copy],
        [^(void (^done)(void)) {
            [recorder.log removeAllObjects];
            bar.text = @"typed";
            [(id<UISearchBarDelegate>)controller searchBarSearchButtonClicked:bar];
            CHECK(controller.active && ![bar isFirstResponder], "the search button leaves the controller active and takes the keyboard away");
            [(id<UISearchBarDelegate>)controller searchBarCancelButtonClicked:bar];
            charon_check(recorder.log.count == 3 && [recorder.log[0] isEqual:@"app cancel"] && [recorder.log[1] isEqual:@"willDismiss active=0"] && [recorder.log[2] isEqual:@"update text="], "cancel tells the application's delegate, then the controller's, and the results are updated with no text", [NSString stringWithFormat:@"%@", recorder.log]);
            CHECK(!controller.active, "the controller is inactive as soon as it starts to dismiss");
            after(1, ^{
                CHECK_EQUAL(recorder.log.lastObject, @"didDismiss active=0", "the delegate hears of the dismissal once it is done");
                CHECK(controller.view.superview == nil && controller.parentViewController == nil, "the search view is gone");
                CHECK(bar.superview == table.tableView && CGRectEqualToRect(bar.frame, CGRectMake(0, 0, table.tableView.bounds.size.width, 44)), "the search bar is back in the table header");
                CHECK(!navigation.navigationBarHidden, "the navigation bar is back");
                CHECK(bar.text.length == 0 && !bar.showsCancelButton, "the text is cleared and the cancel button gone");
                done();
            });
        } copy],
        [^(void (^done)(void)) {
            [recorder.log removeAllObjects];
            controller.active = NO;
            CHECK(recorder.log.count == 0, "making an inactive controller inactive tells nobody");
            controller.hidesNavigationBarDuringPresentation = NO;
            controller.dimsBackgroundDuringPresentation = NO;
            controller.active = YES;
            after(1, ^{
                CHECK(!navigation.navigationBarHidden, "the navigation bar stays when the controller is told to leave it");
                CHECK(((UIView *)controller.view.subviews.firstObject).hidden, "there is no dimming when it is switched off");
                controller.active = NO;
                after(1, ^{
                    CHECK(!controller.active && controller.view.superview == nil, "setting active to NO dismisses");
                    controller.hidesNavigationBarDuringPresentation = YES;
                    controller.dimsBackgroundDuringPresentation = YES;
                    done();
                });
            });
        } copy],
        [^(void (^done)(void)) {
            [recorder.log removeAllObjects];
            recorder.presentsItself = YES;
            recorder.modalHost = table;
            controller.active = YES;
            CHECK_EQUAL(recorder.log, (@[@"presentSearchController", @"update text="]), "a delegate that presents the controller itself is asked to, and hears no will-present and no did-present");
            CHECK(controller.active && table.presentedViewController == controller, "the controller presented by the application is active");
            [recorder.log removeAllObjects];
            controller.active = NO;
            after(1, ^{
                CHECK_EQUAL(recorder.log, (@[@"willDismiss active=0", @"update text=", @"didDismiss active=0"]), "dismissing a presented controller tells the delegate");
                CHECK(table.presentedViewController == nil && !controller.active, "the presented controller is dismissed");
                recorder.presentsItself = NO;
                done();
            });
        } copy],
        [^(void (^done)(void)) {
            UISearchController *modern = [[UISearchController alloc] initWithSearchResultsController:results];
            SearchRecorder *modernRecorder = [[SearchRecorder alloc] init];
            modern.delegate = modernRecorder;
            modern.searchResultsUpdater = modernRecorder;
            CHECK(table.navigationItem.searchController == nil && table.navigationItem.hidesSearchBarWhenScrolling, "a navigation item has no search controller and hides the bar when scrolling, at first");
            table.navigationItem.searchController = modern;
            CHECK(table.navigationItem.searchController == modern && table.navigationItem.titleView == modern.searchBar, "a search controller of a navigation item puts its search bar in the navigation bar");
            CHECK(modern.automaticallyShowsCancelButton && modern.automaticallyShowsSearchResultsController, "the cancel button and the results are shown automatically by default");
            modern.automaticallyShowsCancelButton = NO;
            modern.active = YES;
            after(1, ^{
                CHECK(modern.active && shown(modern.searchBar) && !modern.searchBar.showsCancelButton, "a search started from the navigation bar has no cancel button when it is told not to show one");
                modern.showsSearchResultsController = YES;
                CHECK(!modern.automaticallyShowsSearchResultsController && shown(results.view), "the results can be shown with no text");
                modern.showsSearchResultsController = NO;
                CHECK(!shown(results.view), "and hidden");
                modern.active = NO;
                after(1, ^{
                    CHECK(!modern.active && table.navigationItem.titleView == modern.searchBar && modern.searchBar.superview != nil, "the search bar is back in the navigation bar");
                    table.navigationItem.searchController = nil;
                    CHECK(table.navigationItem.titleView == nil && table.navigationItem.searchController == nil, "taking the search controller away takes the search bar away");
                    done();
                });
            });
        } copy],
        [^(void (^done)(void)) {
            NSTimer *timer = [NSTimer timerWithTimeInterval:0.5 target:[NSBlockOperation blockOperationWithBlock:^{
                NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:searchcontroller_expectations length:strlen(searchcontroller_expectations)] options:0 error:NULL];
                NSMutableDictionary *records = [NSMutableDictionary dictionary];
                searchcontroller_run(self.window, ^(NSString *name, NSString *value) {
                    records[name] = value;
                    printf("record %s: %s\n", name.UTF8String, value.UTF8String);
                });
                for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
                    if ([expected[name] isEqualToString:records[name]])
                        charon_check(YES, name.UTF8String, nil);
                    else if (tolerance(name))
                        printf("tolerated %s: %s\n    device %s\n    host   %s\n", tolerance(name).UTF8String, name.UTF8String, [records[name] UTF8String], [expected[name] UTF8String]);
                    else
                        charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
                }
                done();
            }] selector:@selector(main) userInfo:nil repeats:NO];
            [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        } copy],
    ];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SearchTestDelegate class]));
    }
}
