#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_scaling_key;

@implementation UITextView (RevenantTextScaling13)

- (BOOL)usesStandardTextScaling
{
    return [objc_getAssociatedObject(self, &revenant_scaling_key) boolValue];
}

- (void)setUsesStandardTextScaling:(BOOL)usesStandardTextScaling
{
    if (usesStandardTextScaling)
        revenant_menus_say_once(@"text-scaling", @"UITextView.usesStandardTextScaling: text scaling belongs to Mac Catalyst, so the flag is kept and read back and the text is drawn at its size");
    objc_setAssociatedObject(self, &revenant_scaling_key, @(usesStandardTextScaling), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
