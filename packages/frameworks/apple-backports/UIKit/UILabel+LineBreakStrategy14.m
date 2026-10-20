#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_strategy_key;

@implementation UILabel (RevenantLineBreakStrategy14)

- (NSLineBreakStrategy)lineBreakStrategy
{
    NSNumber *held = objc_getAssociatedObject(self, &revenant_strategy_key);
    return held ? (NSLineBreakStrategy)held.integerValue : NSLineBreakStrategyStandard;
}

- (void)setLineBreakStrategy:(NSLineBreakStrategy)lineBreakStrategy
{
    if (lineBreakStrategy != NSLineBreakStrategyStandard)
        revenant_menus_say_once(@"line-break-strategy", @"UILabel.lineBreakStrategy: iOS 6 breaks lines by its one strategy, so the value is kept and read back and lines break as before");
    objc_setAssociatedObject(self, &revenant_strategy_key, @(lineBreakStrategy), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
