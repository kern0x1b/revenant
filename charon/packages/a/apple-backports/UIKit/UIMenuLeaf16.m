#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// Where a popover for what the element does can come from: the view or bar item
// the element was performed from, as a button's menu gives the button.
static id charon_source_item(id sender)
{
    return [sender isKindOfClass:[UIView class]] || [sender isKindOfClass:[UIBarButtonItem class]] ? sender : nil;
}

@implementation UIAction (CharonMenuLeaf16)

- (id)presentationSourceItem
{
    return charon_source_item(self.sender);
}

// An action's primary action is its handler; there is no selector to send to the target.
- (void)performWithSender:(id)sender target:(id)target
{
    [self charon_performWithSender:sender];
}

@end

@implementation UICommand (CharonMenuLeaf16)

- (id)sender
{
    return objc_getAssociatedObject(self, @selector(sender));
}

- (id)presentationSourceItem
{
    return charon_source_item(self.sender);
}

- (void)performWithSender:(id)sender target:(id)target
{
    [self charon_performWithSender:sender target:target];
}

@end
