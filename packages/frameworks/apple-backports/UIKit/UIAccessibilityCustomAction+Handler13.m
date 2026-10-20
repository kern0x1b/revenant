#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wnonnull"

static const char revenant_handler_key;

@implementation UIAccessibilityCustomAction (RevenantHandler13)

- (instancetype)initWithName:(NSString *)name actionHandler:(UIAccessibilityCustomActionHandler)actionHandler
{
    if ((self = [self initWithName:name target:nil selector:NULL]))
        [self setActionHandler:actionHandler];
    return self;
}

- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName actionHandler:(UIAccessibilityCustomActionHandler)actionHandler
{
    if ((self = [self initWithAttributedName:attributedName target:nil selector:NULL]))
        [self setActionHandler:actionHandler];
    return self;
}

- (UIAccessibilityCustomActionHandler)actionHandler
{
    return objc_getAssociatedObject(self, &revenant_handler_key);
}

- (void)setActionHandler:(UIAccessibilityCustomActionHandler)actionHandler
{
    objc_setAssociatedObject(self, &revenant_handler_key, actionHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
