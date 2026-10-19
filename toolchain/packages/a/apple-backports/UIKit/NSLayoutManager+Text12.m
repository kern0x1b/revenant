#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *LimitsKey = &LimitsKey;

@implementation NSLayoutManager (CharonText12)

- (BOOL)limitsLayoutForSuspiciousContents
{
    return [objc_getAssociatedObject(self, LimitsKey) boolValue];
}

- (void)setLimitsLayoutForSuspiciousContents:(BOOL)limits
{
    objc_setAssociatedObject(self, LimitsKey, @(limits), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
