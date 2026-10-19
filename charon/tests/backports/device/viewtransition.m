#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface TransitionRecorder : UIViewController
@property (nonatomic, strong) NSMutableArray *sizes;
@property (nonatomic, assign) CGAffineTransform transform;
@property (nonatomic, assign) NSInteger alongside;
@property (nonatomic, assign) NSInteger completions;
@property (nonatomic, assign) BOOL animated;
@end

@implementation TransitionRecorder

@synthesize sizes, transform, alongside, completions, animated;

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    if (!self.sizes)
        self.sizes = [NSMutableArray array];
    [self.sizes addObject:NSStringFromCGSize(size)];
    self.transform = coordinator.targetTransform;
    self.animated = coordinator.isAnimated;
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.alongside++;
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.completions++;
    }];
}

@end

@interface ViewTransitionDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ViewTransitionDelegate

- (void)turn:(UIInterfaceOrientation)orientation
{
    [[UIDevice currentDevice] setValue:@(orientation) forKey:@"orientation"];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"viewtransition.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"viewtransition.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillChangeStatusBarOrientationNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        printf("will change %ld\n", (long)[note.userInfo[UIApplicationStatusBarOrientationUserInfoKey] integerValue]);
    }];
    TransitionRecorder *root = [[TransitionRecorder alloc] init];
    TransitionRecorder *child = [[TransitionRecorder alloc] init];
    [root addChildViewController:child];
    [root.view addSubview:child.view];
    [child didMoveToParentViewController:root];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGSize portrait = self.window.bounds.size;
        CGSize landscape = CGSizeMake(portrait.height, portrait.width);
        [self turn:UIInterfaceOrientationLandscapeLeft];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            charon_check(root.sizes.count == 1, "the root is told once", [NSString stringWithFormat:@"%@", root.sizes]);
            charon_check([root.sizes.firstObject isEqualToString:NSStringFromCGSize(landscape)], "the root is told the new size", [NSString stringWithFormat:@"%@ want %@", root.sizes.firstObject, NSStringFromCGSize(landscape)]);
            charon_check(child.sizes.count == 1 && [child.sizes.firstObject isEqualToString:NSStringFromCGSize(landscape)], "a child is told the new size", [NSString stringWithFormat:@"%@", child.sizes]);
            CGFloat angle = atan2(root.transform.b, root.transform.a);
            charon_check(fabs(fabs(angle) - M_PI_2) < 0.01, "the coordinator carries the quarter turn", [NSString stringWithFormat:@"%f", angle]);
            charon_check(root.alongside == 1 && root.completions == 1, "the alongside block and the completion run once", [NSString stringWithFormat:@"%ld %ld", (long)root.alongside, (long)root.completions]);
            [self turn:UIInterfaceOrientationLandscapeLeft];
            charon_check(root.sizes.count == 1, "the same orientation is not a transition", nil);
            [self turn:UIInterfaceOrientationPortrait];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                charon_check(root.sizes.count == 2 && [root.sizes.lastObject isEqualToString:NSStringFromCGSize(portrait)], "turning back tells the old size", [NSString stringWithFormat:@"%@", root.sizes]);
                charon_check(child.sizes.count == 2, "the child hears it too", nil);
                printf("checks=%d failures=%d\n", charon_checks, charon_failures);
                NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
                [summary writeToFile:[results_folder stringByAppendingPathComponent:@"viewtransition.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            });
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ViewTransitionDelegate class]));
    }
}
