#import "../app/revenant_check.h"
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

@interface RevenantNullActionDelegate : NSObject
@property (nonatomic, strong) id null;
@end

@implementation RevenantNullActionDelegate
- (id)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    return self.null;
}
@end

static NSString *revenant_run_null_actions(id null)
{
    @try {
        NSDictionary *actions = @{@"onOrderIn": null, @"onOrderOut": null, @"position": null, @"bounds": null,
                                  @"opacity": null, @"sublayers": null, @"hidden": null, @"contents": null};
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        view.layer.actions = actions;
        RevenantNullActionDelegate *delegate = [[RevenantNullActionDelegate alloc] init];
        delegate.null = null;
        CALayer *child = [CALayer layer];
        child.delegate = (id)delegate;
        [window addSubview:view];
        [window.layer addSublayer:child];
        view.layer.position = CGPointMake(40, 40);
        view.layer.bounds = CGRectMake(0, 0, 60, 60);
        view.layer.opacity = 0.5;
        child.position = CGPointMake(10, 10);
        child.bounds = CGRectMake(0, 0, 20, 20);
        child.opacity = 0.5;
        [CATransaction flush];
        [child removeFromSuperlayer];
        [view removeFromSuperview];
        [CATransaction flush];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return nil;
}

REVENANT_CASE(quartzcore_nsnull_action)
{
    Class bound = revenant_backport_class("Foundation", "NSNull");
    id made = [[bound alloc] init];
    BOOL singleton = made == (id)kCFNull && made == [NSNull null];
    revenant_expect_true(@"an NSNull made by alloc and init is the null singleton", singleton != (BOOL)negative,
                         [NSString stringWithFormat:@"class %@, object %p, kCFNull %p", [made class], (__bridge void *)made, kCFNull]);

    NSString *raised = revenant_run_null_actions(made);
    revenant_expect_true(@"the null singleton as an action ends the search without a message to it", (raised == nil) != (BOOL)negative,
                         raised ?: @"no exception");
}
