#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface WatchController : UIViewController
@property (nonatomic, strong) NSMutableArray *log;
@property (nonatomic) BOOL alongside;
@property (nonatomic, strong) UIView *box;
@end

@implementation WatchController

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    view.backgroundColor = [UIColor whiteColor];
    self.box = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 80, 80)];
    self.box.backgroundColor = [UIColor redColor];
    [view addSubview:self.box];
    self.view = view;
}

- (void)note:(NSString *)what
{
    id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
    [self.log addObject:[NSString stringWithFormat:@"%@ %@ %@", self.title, what, coordinator ? (coordinator.isAnimated ? @"animated" : @"immediate") : @"none"]];
    if (coordinator && self.alongside && [what isEqual:@"willAppear"]) {
        __block BOOL ran = NO;
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            ran = YES;
            self.box.alpha = 0.2f;
            self.box.frame = CGRectMake(200, 100, 80, 80);
        } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            [self.log addObject:[NSString stringWithFormat:@"%@ alongside done cancelled %d", self.title, context.isCancelled]];
        }];
        [self.log addObject:[NSString stringWithFormat:@"%@ alongside ran %d", self.title, ran]];
    }
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self note:@"willAppear"]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self note:@"didAppear"]; if ([self.title isEqual:@"pushed"] || [self.title isEqual:@"root"]) printf("%s didAppear at %.3f\n", self.title.UTF8String, CACurrentMediaTime()); }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self note:@"willDisappear"]; }

@end

@interface TransitionDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableArray *log;
@end

@implementation TransitionDelegate

- (WatchController *)make:(NSString *)title
{
    WatchController *controller = [[WatchController alloc] init];
    controller.title = title;
    controller.log = self.log;
    return controller;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"transition.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"transition.log"]);
    self.log = [NSMutableArray array];
    WatchController *root = [self make:@"root"];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self run:navigation root:root]; });
    return YES;
}

- (void)step:(NSTimeInterval)delay block:(void (^)(void))block
{
    static NSTimeInterval total = 0;
    total += delay;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(total * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

- (void)run:(UINavigationController *)navigation root:(WatchController *)root
{
    CHECK(root.transitionCoordinator == nil, "a controller that is not in a transition has no coordinator");
    __block WatchController *pushed = [self make:@"pushed"];
    pushed.alongside = YES;
    __block CFTimeInterval started;
    [self step:0.1 block:^{
        started = CACurrentMediaTime();
        printf("push start %.3f\n", started);
        [navigation pushViewController:pushed animated:YES];
        CHECK(pushed.transitionCoordinator != nil && root.transitionCoordinator == pushed.transitionCoordinator, "a push gives both controllers the same coordinator");
        id<UIViewControllerTransitionCoordinator> coordinator = pushed.transitionCoordinator;
        CHECK([coordinator viewControllerForKey:UITransitionContextFromViewControllerKey] == root && [coordinator viewControllerForKey:UITransitionContextToViewControllerKey] == pushed, "which knows the two controllers");
        CHECK(coordinator.isAnimated && !coordinator.isInteractive && !coordinator.isCancelled, "and is animated, not interactive, not cancelled");
    }];
    [self step:1.2 block:^{
        printf("push wall %.2f\n", CACurrentMediaTime() - started);
        CHECK(pushed.transitionCoordinator == nil && root.transitionCoordinator == nil, "the coordinator is gone when the push is over");
        NSArray *expected = @[@"pushed willAppear animated", @"pushed alongside ran 1", @"root willDisappear animated", @"pushed alongside done cancelled 0"];
        for (NSString *line in expected)
            CHECK([self.log containsObject:line], [[@"log has: " stringByAppendingString:line] UTF8String]);
        CHECK(pushed.box.frame.origin.x == 200 && pushed.box.alpha < 0.3f, "the animation given to animateAlongsideTransition ran");
    }];
    [self step:0.1 block:^{
        [self.log removeAllObjects];
        printf("pop start %.3f\n", CACurrentMediaTime());
        [navigation popViewControllerAnimated:YES];
        CHECK(pushed.transitionCoordinator != nil && root.transitionCoordinator == pushed.transitionCoordinator, "a pop gives both controllers a coordinator too");
        CHECK([pushed.transitionCoordinator viewControllerForKey:UITransitionContextFromViewControllerKey] == pushed, "with the popped one as the from controller");
    }];
    [self step:1.0 block:^{
        CHECK(root.transitionCoordinator == nil, "and it is gone when the pop is over");
        CHECK([self.log containsObject:@"pushed willDisappear animated"] && [self.log containsObject:@"root willAppear animated"], "the appearance callbacks of the pop saw it");
    }];

    __block WatchController *modal = [self make:@"modal"];
    modal.alongside = YES;
    __block BOOL presented = NO, completed = NO;
    [self step:0.2 block:^{
        [self.log removeAllObjects];
        started = CACurrentMediaTime();
        [navigation presentViewController:modal animated:YES completion:^{ presented = YES; printf("present took %.2f\n", CACurrentMediaTime() - started); }];
        CHECK(modal.transitionCoordinator != nil, "a presentation gives the presented controller a coordinator");
        CHECK(modal.transitionCoordinator.isAnimated, "which is animated");
    }];
    [self step:1.2 block:^{
        CHECK(presented && modal.transitionCoordinator == nil, "it is gone when the presentation is over");
        CHECK([self.log containsObject:@"modal alongside ran 1"] && [self.log containsObject:@"modal alongside done cancelled 0"], "and the alongside animation ran and finished");
    }];
    [self step:0.1 block:^{
        [self.log removeAllObjects];
        started = CACurrentMediaTime();
        [navigation dismissViewControllerAnimated:YES completion:^{ completed = YES; printf("dismiss took %.2f\n", CACurrentMediaTime() - started); }];
        CHECK(modal.transitionCoordinator != nil, "a dismissal gives the presented controller a coordinator");
    }];
    [self step:1.2 block:^{
        CHECK(completed && modal.transitionCoordinator == nil, "and it is gone when the dismissal is over");
    }];
    __block WatchController *silent = [self make:@"silent"];
    silent.alongside = YES;
    [self step:0.2 block:^{
        [self.log removeAllObjects];
        [navigation presentViewController:silent animated:NO completion:nil];
        CHECK([self.log containsObject:@"silent alongside ran 1"], "without animation the alongside block runs at once");
        CHECK(silent.box.frame.origin.x == 200, "and its result is there");
    }];
    [self step:0.5 block:^{
        CHECK([self.log containsObject:@"silent alongside done cancelled 0"] && silent.transitionCoordinator == nil, "and its completion is called");
        [navigation dismissViewControllerAnimated:NO completion:nil];
    }];
    [self step:0.6 block:^{
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"transition.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TransitionDelegate class]));
    }
}
