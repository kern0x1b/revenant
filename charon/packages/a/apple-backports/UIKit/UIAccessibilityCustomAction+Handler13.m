#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wnonnull"

static const char charon_handler_key;

@implementation UIAccessibilityCustomAction (CharonHandler13)

- (instancetype)initWithName:(NSString *)name actionHandler:(UIAccessibilityCustomActionHandler)actionHandler
{
    if ((self = [self initWithName:name target:nil selector:NULL]))
        [self setActionHandler:actionHandler];   // a send, not a dot-syntax write: a write is renamed by the
    // property name it reads, and a category on a host class has both the accessor and the setter renamed,
    // so only a send keeps the two the same name
    return self;
}

// The attributed name with a handler, which is the iOS 13 member beside the plain one above. Both
// halves are already the port's own: the attributed name and its attributes are
// UIAccessibilityCustomAction+AttributedName11.m, the handler is in this file, so this is their
// composition and adds no state of its own. The host's answers, measured under Mac Catalyst
// (`.agent-work/runs/gb04uikit13/probe/host-action.m`): `name` is the attributed string, and
// `attributedName` is not nil and keeps the attributes it was given. A nil attributed name still
// makes an action, whose name and attributed name are both empty; a nil handler makes an action
// with the name and no handler. Both follow from the two lines below rather than from a branch, so
// they are what the same two lines give.
- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName actionHandler:(UIAccessibilityCustomActionHandler)actionHandler
{
    if ((self = [self initWithAttributedName:attributedName target:nil selector:NULL]))
        [self setActionHandler:actionHandler];   // a send, for the reason given above
    return self;
}

- (UIAccessibilityCustomActionHandler)actionHandler
{
    return objc_getAssociatedObject(self, &charon_handler_key);
}

- (void)setActionHandler:(UIAccessibilityCustomActionHandler)actionHandler
{
    objc_setAssociatedObject(self, &charon_handler_key, actionHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
