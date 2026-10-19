#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_scaling_key;

@implementation UITextView (CharonTextScaling13)

- (BOOL)usesStandardTextScaling
{
    return [objc_getAssociatedObject(self, &charon_scaling_key) boolValue];
}

- (void)setUsesStandardTextScaling:(BOOL)usesStandardTextScaling
{
    if (usesStandardTextScaling)
        charon_menus_say_once(@"text-scaling", @"UITextView.usesStandardTextScaling: text scaling belongs to Mac Catalyst, so the flag is kept and read back and the text is drawn at its size");
    objc_setAssociatedObject(self, &charon_scaling_key, @(usesStandardTextScaling), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
