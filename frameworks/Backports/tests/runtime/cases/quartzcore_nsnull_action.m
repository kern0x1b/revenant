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

REVENANT_CASE(quartzcore_nsnull_action)
{
    id null = [[NSNull alloc] init];
    BOOL singleton = null == (id)kCFNull && null == [NSNull null];
    revenant_expect_true(@"an NSNull made by alloc and init is the null singleton", singleton != (BOOL)negative,
                         [NSString stringWithFormat:@"class %@, object %p, kCFNull %p", [null class], null, kCFNull]);

    NSString *raised = nil;
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
        raised = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    revenant_expect_true(@"an NSNull action ends the search without a message to it", (raised == nil) != (BOOL)negative,
                         raised ?: @"no exception");
}
