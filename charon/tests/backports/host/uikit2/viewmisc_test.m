#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface UIView (CharonHostViewMisc)
- (UIView *)charonHostMaskView;
- (void)charonHostSetMaskView:(UIView *)view;
+ (void)charonHostPerformWithoutAnimation:(void (^)(void))block;
- (NSInteger)charonHostSemanticContentAttribute;
- (void)charonHostSetSemanticContentAttribute:(NSInteger)attribute;
- (NSInteger)charonHostEffectiveUserInterfaceLayoutDirection;
+ (NSInteger)charonHostUserInterfaceLayoutDirectionForSemanticContentAttribute:(NSInteger)attribute;
+ (NSInteger)charonHostUserInterfaceLayoutDirectionForSemanticContentAttribute:(NSInteger)attribute relativeToLayoutDirection:(NSInteger)direction;
@end

@interface UIViewController (CharonHostViewMisc)
- (UIView *)charonHostViewIfLoaded;
- (void)charonHostLoadViewIfNeeded;
- (CGSize)charonHostPreferredContentSize;
- (void)charonHostSetPreferredContentSize:(CGSize)size;
- (NSInteger)charonHostPreferredStatusBarStyle;
- (BOOL)charonHostPrefersStatusBarHidden;
- (NSInteger)charonHostPreferredStatusBarUpdateAnimation;
- (UIViewController *)charonHostChildViewControllerForStatusBarStyle;
- (UIViewController *)charonHostChildViewControllerForStatusBarHidden;
- (BOOL)charonHostModalPresentationCapturesStatusBarAppearance;
- (void)charonHostSetModalPresentationCapturesStatusBarAppearance:(BOOL)captures;
@end

@interface LoadingController : UIViewController
@property (nonatomic) NSInteger loads;
@property (nonatomic) NSInteger didLoads;
@end

@implementation LoadingController

- (void)loadView
{
    self.loads++;
    self.view = [[UIView alloc] init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.didLoads++;
}

@end

int main(void)
{
    @autoreleasepool {
        for (NSInteger direction = 0; direction < 2; direction++) {
            for (NSInteger attribute = 0; attribute < 5; attribute++) {
                charon_check([UIView charonHostUserInterfaceLayoutDirectionForSemanticContentAttribute:attribute relativeToLayoutDirection:direction] ==
                                 [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute relativeToLayoutDirection:(UIUserInterfaceLayoutDirection)direction],
                             NAMED(@"layout direction of attribute %ld relative to %ld", (long)attribute, (long)direction), @"the direction differs");
            }
        }
        for (NSInteger attribute = 0; attribute < 5; attribute++) {
            charon_check([UIView charonHostUserInterfaceLayoutDirectionForSemanticContentAttribute:attribute] == [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute],
                         NAMED(@"layout direction of attribute %ld", (long)attribute), @"the direction differs");
            UIView *ours = [[UIView alloc] init], *system = [[UIView alloc] init];
            [ours charonHostSetSemanticContentAttribute:attribute];
            system.semanticContentAttribute = (UISemanticContentAttribute)attribute;
            charon_check([ours charonHostSemanticContentAttribute] == system.semanticContentAttribute, NAMED(@"attribute %ld is kept", (long)attribute), @"the attribute differs");
            charon_check([ours charonHostEffectiveUserInterfaceLayoutDirection] == system.effectiveUserInterfaceLayoutDirection, NAMED(@"effective direction of attribute %ld", (long)attribute), @"the direction differs");
        }
        UIView *ourParent = [[UIView alloc] init], *ourChild = [[UIView alloc] init], *parent = [[UIView alloc] init], *child = [[UIView alloc] init];
        [ourParent addSubview:ourChild];
        [parent addSubview:child];
        [ourParent charonHostSetSemanticContentAttribute:4];
        parent.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        charon_check([ourChild charonHostEffectiveUserInterfaceLayoutDirection] == child.effectiveUserInterfaceLayoutDirection, "a child does not take its parent's attribute", @"the direction differs");

        UIView *ourHost = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)], *systemHost = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
        UIView *ourMask = [[UIView alloc] initWithFrame:CGRectMake(5, 5, 10, 10)], *systemMask = [[UIView alloc] initWithFrame:CGRectMake(5, 5, 10, 10)];
        charon_check([ourHost charonHostMaskView] == nil && systemHost.maskView == nil, "no mask view at first", @"a mask view is there");
        [ourHost charonHostSetMaskView:ourMask];
        systemHost.maskView = systemMask;
        charon_check([ourHost charonHostMaskView] == ourMask && systemHost.maskView == systemMask, "the mask view is the one set", @"the mask view differs");
        charon_check((ourHost.layer.mask == ourMask.layer) == (systemHost.layer.mask == systemMask.layer) && ourHost.layer.mask != nil, "the mask view's layer is the layer's mask", @"the mask differs");
        charon_check(ourHost.subviews.count == systemHost.subviews.count, "the mask view is not a subview", @"the subviews differ");
        charon_check(CGRectEqualToRect(ourMask.frame, systemMask.frame), "the mask view keeps its frame", @"the frame differs");
        [ourHost charonHostSetMaskView:ourMask];
        systemHost.maskView = systemMask;
        charon_check(ourHost.layer.mask == ourMask.layer && systemHost.layer.mask == systemMask.layer, "setting the mask view again changes nothing", @"the mask went");
        UIView *ourNext = [[UIView alloc] init], *systemNext = [[UIView alloc] init];
        [ourHost charonHostSetMaskView:ourNext];
        systemHost.maskView = systemNext;
        charon_check(ourMask.superview == nil && systemMask.superview == nil && ourHost.layer.mask == ourNext.layer && systemHost.layer.mask == systemNext.layer, "another mask view replaces the first", @"the replacement differs");
        UIView *ourElsewhere = [[UIView alloc] init], *systemElsewhere = [[UIView alloc] init];
        UIView *ourTaken = [[UIView alloc] init], *systemTaken = [[UIView alloc] init];
        [ourElsewhere addSubview:ourTaken];
        [systemElsewhere addSubview:systemTaken];
        [ourHost charonHostSetMaskView:ourTaken];
        systemHost.maskView = systemTaken;
        charon_check(ourElsewhere.subviews.count == systemElsewhere.subviews.count, "a view taken as the mask leaves its superview", @"the superview keeps it");
        [ourHost charonHostSetMaskView:nil];
        systemHost.maskView = nil;
        charon_check(ourHost.layer.mask == nil && systemHost.layer.mask == nil && ourHost.layer.mask == systemHost.layer.mask, "no mask view, no mask", @"a mask stays");
        NSString *ourRaise = nil, *systemRaise = nil;
        @try { [ourHost charonHostSetMaskView:ourHost]; } @catch (NSException *exception) { ourRaise = exception.name; }
        @try { systemHost.maskView = systemHost; } @catch (NSException *exception) { systemRaise = exception.name; }
        charon_check([ourRaise isEqualToString:systemRaise] && ourRaise != nil, "a view as its own mask raises", [NSString stringWithFormat:@"%@ != %@", ourRaise, systemRaise]);

        __block BOOL ranOurs = NO, ranSystem = NO, insideOurs = YES, insideSystem = YES;
        [UIView charonHostPerformWithoutAnimation:^{ ranOurs = YES; insideOurs = [UIView areAnimationsEnabled]; }];
        [UIView performWithoutAnimation:^{ ranSystem = YES; insideSystem = [UIView areAnimationsEnabled]; }];
        charon_check(ranOurs == ranSystem && insideOurs == insideSystem && [UIView areAnimationsEnabled], "animations are off inside the block and back after it", @"the setting differs");
        [UIView setAnimationsEnabled:NO];
        [UIView charonHostPerformWithoutAnimation:^{}];
        BOOL afterOurs = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:YES];
        [UIView setAnimationsEnabled:NO];
        [UIView performWithoutAnimation:^{}];
        BOOL afterSystem = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:YES];
        charon_check(afterOurs == afterSystem && !afterOurs, "animations stay off when they were off", @"the setting differs");
        @try { [UIView charonHostPerformWithoutAnimation:^{ @throw [NSException exceptionWithName:@"X" reason:@"r" userInfo:nil]; }]; } @catch (NSException *exception) {}
        BOOL raisedOurs = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:YES];
        @try { [UIView performWithoutAnimation:^{ @throw [NSException exceptionWithName:@"X" reason:@"r" userInfo:nil]; }]; } @catch (NSException *exception) {}
        BOOL raisedSystem = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:YES];
        charon_check(raisedOurs == raisedSystem, "a block that raises leaves the animations as the system does", [NSString stringWithFormat:@"%d != %d", raisedOurs, raisedSystem]);

        LoadingController *ours = [[LoadingController alloc] init], *system = [[LoadingController alloc] init];
        charon_check([ours charonHostViewIfLoaded] == nil && system.viewIfLoaded == nil && ours.loads == 0 && system.loads == 0, "viewIfLoaded does not load the view", @"the view was loaded");
        [ours charonHostLoadViewIfNeeded];
        [system loadViewIfNeeded];
        charon_check(ours.loads == system.loads && ours.didLoads == system.didLoads && ours.loads == 1 && ours.didLoads == 1, "loadViewIfNeeded loads the view and runs viewDidLoad", [NSString stringWithFormat:@"%ld %ld", (long)ours.loads, (long)ours.didLoads]);
        [ours charonHostLoadViewIfNeeded];
        [system loadViewIfNeeded];
        charon_check(ours.loads == 1 && system.loads == 1 && [ours charonHostViewIfLoaded] == ours.view && system.viewIfLoaded == system.view, "loadViewIfNeeded loads once and viewIfLoaded answers the view", @"the view was loaded twice");

        UIViewController *fresh = [[UIViewController alloc] init], *freshSystem = [[UIViewController alloc] init];
        charon_check(CGSizeEqualToSize([fresh charonHostPreferredContentSize], freshSystem.preferredContentSize), "the preferred content size of a new controller", @"the size differs");
        [fresh charonHostSetPreferredContentSize:CGSizeMake(320, 480)];
        freshSystem.preferredContentSize = CGSizeMake(320, 480);
        charon_check(CGSizeEqualToSize([fresh charonHostPreferredContentSize], freshSystem.preferredContentSize), "the preferred content size is kept", @"the size differs");
        charon_check([fresh charonHostPreferredStatusBarStyle] == freshSystem.preferredStatusBarStyle && [fresh charonHostPrefersStatusBarHidden] == freshSystem.prefersStatusBarHidden &&
                         [fresh charonHostPreferredStatusBarUpdateAnimation] == freshSystem.preferredStatusBarUpdateAnimation, "the status bar preferences of a new controller", @"a preference differs");
        charon_check([fresh charonHostChildViewControllerForStatusBarStyle] == freshSystem.childViewControllerForStatusBarStyle && [fresh charonHostChildViewControllerForStatusBarHidden] == freshSystem.childViewControllerForStatusBarHidden,
                     "no controller child answers for the status bar", @"a child differs");
        charon_check([fresh charonHostModalPresentationCapturesStatusBarAppearance] == freshSystem.modalPresentationCapturesStatusBarAppearance, "a presentation captures the status bar as the system does at first", @"the flag differs");
        [fresh charonHostSetModalPresentationCapturesStatusBarAppearance:YES];
        freshSystem.modalPresentationCapturesStatusBarAppearance = YES;
        charon_check([fresh charonHostModalPresentationCapturesStatusBarAppearance] == freshSystem.modalPresentationCapturesStatusBarAppearance, "the capture flag is kept", @"the flag differs");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
