#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static id charon_source_item(id sender)
{
    return [sender isKindOfClass:[UIView class]] || [sender isKindOfClass:[UIBarButtonItem class]] ? sender : nil;
}

@implementation UIAction (CharonMenuLeaf16)

- (id)presentationSourceItem
{
    return charon_source_item(self.sender);
}

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
