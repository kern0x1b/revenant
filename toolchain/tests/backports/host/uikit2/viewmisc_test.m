#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface UIView (RevenantHostViewMisc)
- (UIView *)revenantHostMaskView;
- (void)revenantHostSetMaskView:(UIView *)view;
+ (void)revenantHostPerformWithoutAnimation:(void (^)(void))block;
- (NSInteger)revenantHostSemanticContentAttribute;
- (void)revenantHostSetSemanticContentAttribute:(NSInteger)attribute;
- (NSInteger)revenantHostEffectiveUserInterfaceLayoutDirection;
+ (NSInteger)revenantHostUserInterfaceLayoutDirectionForSemanticContentAttribute:(NSInteger)attribute;
+ (NSInteger)revenantHostUserInterfaceLayoutDirectionForSemanticContentAttribute:(NSInteger)attribute relativeToLayoutDirection:(NSInteger)direction;
@end

@interface UIViewController (RevenantHostViewMisc)
- (UIView *)revenantHostViewIfLoaded;
- (void)revenantHostLoadViewIfNeeded;
- (CGSize)revenantHostPreferredContentSize;
- (void)revenantHostSetPreferredContentSize:(CGSize)size;
- (NSInteger)revenantHostPreferredStatusBarStyle;
- (BOOL)revenantHostPrefersStatusBarHidden;
- (NSInteger)revenantHostPreferredStatusBarUpdateAnimation;
- (UIViewController *)revenantHostChildViewControllerForStatusBarStyle;
- (UIViewController *)revenantHostChildViewControllerForStatusBarHidden;
- (BOOL)revenantHostModalPresentationCapturesStatusBarAppearance;
- (void)revenantHostSetModalPresentationCapturesStatusBarAppearance:(BOOL)captures;
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
                revenant_check([UIView revenantHostUserInterfaceLayoutDirectionForSemanticContentAttribute:attribute relativeToLayoutDirection:direction] ==
                                 [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute relativeToLayoutDirection:(UIUserInterfaceLayoutDirection)direction],
                             NAMED(@"layout direction of attribute %ld relative to %ld", (long)attribute, (long)direction), @"the direction differs");
            }
        }
        for (NSInteger attribute = 0; attribute < 5; attribute++) {
            revenant_check([UIView revenantHostUserInterfaceLayoutDirectionForSemanticContentAttribute:attribute] == [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute],
                         NAMED(@"layout direction of attribute %ld", (long)attribute), @"the direction differs");
            UIView *ours = [[UIView alloc] init], *system = [[UIView alloc] init];
            [ours revenantHostSetSemanticContentAttribute:attribute];
            system.semanticContentAttribute = (UISemanticContentAttribute)attribute;
            revenant_check([ours revenantHostSemanticContentAttribute] == system.semanticContentAttribute, NAMED(@"attribute %ld is kept", (long)attribute), @"the attribute differs");
            revenant_check([ours revenantHostEffectiveUserInterfaceLayoutDirection] == system.effectiveUserInterfaceLayoutDirection, NAMED(@"effective direction of attribute %ld", (long)attribute), @"the direction differs");
        }
        UIView *ourParent = [[UIView alloc] init], *ourChild = [[UIView alloc] init], *parent = [[UIView alloc] init], *child = [[UIView alloc] init];
        [ourParent addSubview:ourChild];
        [parent addSubview:child];
        [ourParent revenantHostSetSemanticContentAttribute:4];
        parent.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        revenant_check([ourChild revenantHostEffectiveUserInterfaceLayoutDirection] == child.effectiveUserInterfaceLayoutDirection, "a child does not take its parent's attribute", @"the direction differs");

        UIView *ourHost = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)], *systemHost = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
        UIView *ourMask = [[UIView alloc] initWithFrame:CGRectMake(5, 5, 10, 10)], *systemMask = [[UIView alloc] initWithFrame:CGRectMake(5, 5, 10, 10)];
        revenant_check([ourHost revenantHostMaskView] == nil && systemHost.maskView == nil, "no mask view at first", @"a mask view is there");
        [ourHost revenantHostSetMaskView:ourMask];
        systemHost.maskView = systemMask;
        revenant_check([ourHost revenantHostMaskView] == ourMask && systemHost.maskView == systemMask, "the mask view is the one set", @"the mask view differs");
        revenant_check((ourHost.layer.mask == ourMask.layer) == (systemHost.layer.mask == systemMask.layer) && ourHost.layer.mask != nil, "the mask view's layer is the layer's mask", @"the mask differs");
        revenant_check(ourHost.subviews.count == systemHost.subviews.count, "the mask view is not a subview", @"the subviews differ");
        revenant_check(CGRectEqualToRect(ourMask.frame, systemMask.frame), "the mask view keeps its frame", @"the frame differs");
        [ourHost revenantHostSetMaskView:ourMask];
        systemHost.maskView = systemMask;
        revenant_check(ourHost.layer.mask == ourMask.layer && systemHost.layer.mask == systemMask.layer, "setting the mask view again changes nothing", @"the mask went");
        UIView *ourNext = [[UIView alloc] init], *systemNext = [[UIView alloc] init];
        [ourHost revenantHostSetMaskView:ourNext];
        systemHost.maskView = systemNext;
        revenant_check(ourMask.superview == nil && systemMask.superview == nil && ourHost.layer.mask == ourNext.layer && systemHost.layer.mask == systemNext.layer, "another mask view replaces the first", @"the replacement differs");
        UIView *ourElsewhere = [[UIView alloc] init], *systemElsewhere = [[UIView alloc] init];
        UIView *ourTaken = [[UIView alloc] init], *systemTaken = [[UIView alloc] init];
        [ourElsewhere addSubview:ourTaken];
        [systemElsewhere addSubview:systemTaken];
        [ourHost revenantHostSetMaskView:ourTaken];
        systemHost.maskView = systemTaken;
        revenant_check(ourElsewhere.subviews.count == systemElsewhere.subviews.count, "a view taken as the mask leaves its superview", @"the superview keeps it");
        [ourHost revenantHostSetMaskView:nil];
        systemHost.maskView = nil;
        revenant_check(ourHost.layer.mask == nil && systemHost.layer.mask == nil && ourHost.layer.mask == systemHost.layer.mask, "no mask view, no mask", @"a mask stays");
        NSString *ourRaise = nil, *systemRaise = nil;
        @try { [ourHost revenantHostSetMaskView:ourHost]; } @catch (NSException *exception) { ourRaise = exception.name; }
        @try { systemHost.maskView = systemHost; } @catch (NSException *exception) { systemRaise = exception.name; }
        revenant_check([ourRaise isEqualToString:systemRaise] && ourRaise != nil, "a view as its own mask raises", [NSString stringWithFormat:@"%@ != %@", ourRaise, systemRaise]);

        __block BOOL ranOurs = NO, ranSystem = NO, insideOurs = YES, insideSystem = YES;
        [UIView revenantHostPerformWithoutAnimation:^{ ranOurs = YES; insideOurs = [UIView areAnimationsEnabled]; }];
        [UIView performWithoutAnimation:^{ ranSystem = YES; insideSystem = [UIView areAnimationsEnabled]; }];
        revenant_check(ranOurs == ranSystem && insideOurs == insideSystem && [UIView areAnimationsEnabled], "animations are off inside the block and back after it", @"the setting differs");
        [UIView setAnimationsEnabled:NO];
        [UIView revenantHostPerformWithoutAnimation:^{}];
        BOOL afterOurs = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:YES];
        [UIView setAnimationsEnabled:NO];
        [UIView performWithoutAnimation:^{}];
        BOOL afterSystem = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:YES];
        revenant_check(afterOurs == afterSystem && !afterOurs, "animations stay off when they were off", @"the setting differs");
        @try { [UIView revenantHostPerformWithoutAnimation:^{ @throw [NSException exceptionWithName:@"X" reason:@"r" userInfo:nil]; }]; } @catch (NSException *exception) {}
        BOOL raisedOurs = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:YES];
        @try { [UIView performWithoutAnimation:^{ @throw [NSException exceptionWithName:@"X" reason:@"r" userInfo:nil]; }]; } @catch (NSException *exception) {}
        BOOL raisedSystem = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:YES];
        revenant_check(raisedOurs == raisedSystem, "a block that raises leaves the animations as the system does", [NSString stringWithFormat:@"%d != %d", raisedOurs, raisedSystem]);

        LoadingController *ours = [[LoadingController alloc] init], *system = [[LoadingController alloc] init];
        revenant_check([ours revenantHostViewIfLoaded] == nil && system.viewIfLoaded == nil && ours.loads == 0 && system.loads == 0, "viewIfLoaded does not load the view", @"the view was loaded");
        [ours revenantHostLoadViewIfNeeded];
        [system loadViewIfNeeded];
        revenant_check(ours.loads == system.loads && ours.didLoads == system.didLoads && ours.loads == 1 && ours.didLoads == 1, "loadViewIfNeeded loads the view and runs viewDidLoad", [NSString stringWithFormat:@"%ld %ld", (long)ours.loads, (long)ours.didLoads]);
        [ours revenantHostLoadViewIfNeeded];
        [system loadViewIfNeeded];
        revenant_check(ours.loads == 1 && system.loads == 1 && [ours revenantHostViewIfLoaded] == ours.view && system.viewIfLoaded == system.view, "loadViewIfNeeded loads once and viewIfLoaded answers the view", @"the view was loaded twice");

        UIViewController *fresh = [[UIViewController alloc] init], *freshSystem = [[UIViewController alloc] init];
        revenant_check(CGSizeEqualToSize([fresh revenantHostPreferredContentSize], freshSystem.preferredContentSize), "the preferred content size of a new controller", @"the size differs");
        [fresh revenantHostSetPreferredContentSize:CGSizeMake(320, 480)];
        freshSystem.preferredContentSize = CGSizeMake(320, 480);
        revenant_check(CGSizeEqualToSize([fresh revenantHostPreferredContentSize], freshSystem.preferredContentSize), "the preferred content size is kept", @"the size differs");
        revenant_check([fresh revenantHostPreferredStatusBarStyle] == freshSystem.preferredStatusBarStyle && [fresh revenantHostPrefersStatusBarHidden] == freshSystem.prefersStatusBarHidden &&
                         [fresh revenantHostPreferredStatusBarUpdateAnimation] == freshSystem.preferredStatusBarUpdateAnimation, "the status bar preferences of a new controller", @"a preference differs");
        revenant_check([fresh revenantHostChildViewControllerForStatusBarStyle] == freshSystem.childViewControllerForStatusBarStyle && [fresh revenantHostChildViewControllerForStatusBarHidden] == freshSystem.childViewControllerForStatusBarHidden,
                     "no controller child answers for the status bar", @"a child differs");
        revenant_check([fresh revenantHostModalPresentationCapturesStatusBarAppearance] == freshSystem.modalPresentationCapturesStatusBarAppearance, "a presentation captures the status bar as the system does at first", @"the flag differs");
        [fresh revenantHostSetModalPresentationCapturesStatusBarAppearance:YES];
        freshSystem.modalPresentationCapturesStatusBarAppearance = YES;
        revenant_check([fresh revenantHostModalPresentationCapturesStatusBarAppearance] == freshSystem.modalPresentationCapturesStatusBarAppearance, "the capture flag is kept", @"the flag differs");
    }
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures;
}
