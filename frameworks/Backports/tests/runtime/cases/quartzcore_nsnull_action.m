#import "../app/revenant_check.h"
#import <QuartzCore/QuartzCore.h>

@interface RevenantNullActionDelegate : NSObject
@end

@implementation RevenantNullActionDelegate
- (id)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    return (id)[NSNull null];
}
@end

REVENANT_CASE(quartzcore_nsnull_action)
{
    CALayer *root = [CALayer layer];
    CALayer *child = [CALayer layer];
    RevenantNullActionDelegate *delegate = [[RevenantNullActionDelegate alloc] init];
    child.delegate = (id)delegate;
    child.actions = @{@"onOrderIn": [NSNull null], @"onOrderOut": [NSNull null],
                      @"position": [NSNull null], @"bounds": [NSNull null]};
    [root addSublayer:child];
    [root layoutIfNeeded];
    BOOL responds = [NSNull instancesRespondToSelector:@selector(runActionForKey:object:arguments:)];
    revenant_expect_true(@"NSNull is a null CAAction", responds != (BOOL)negative,
                         responds ? @"it implements runActionForKey:object:arguments:" : @"it does not");
}
