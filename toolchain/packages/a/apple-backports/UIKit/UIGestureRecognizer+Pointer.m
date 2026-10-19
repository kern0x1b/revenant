#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char RevenantButtonMaskRequiredKey;

@implementation UIGestureRecognizer (RevenantPointer)

- (UIKeyModifierFlags)modifierFlags
{
    return 0;
}

- (UIEventButtonMask)buttonMask
{
    return 0;
}

- (BOOL)shouldReceiveEvent:(UIEvent *)event
{
    return YES;
}

@end

@implementation UITapGestureRecognizer (RevenantPointer)

- (UIEventButtonMask)buttonMaskRequired
{
    NSNumber *held = objc_getAssociatedObject(self, &RevenantButtonMaskRequiredKey);
    return held ? (UIEventButtonMask)held.integerValue : UIEventButtonMaskPrimary;
}

- (void)setButtonMaskRequired:(UIEventButtonMask)buttonMaskRequired
{
    if (buttonMaskRequired <= 0)
        [NSException raise:NSInternalInconsistencyException format:@"buttonMaskRequired must be greater than 0"];
    objc_setAssociatedObject(self, &RevenantButtonMaskRequiredKey, @((NSInteger)buttonMaskRequired), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
