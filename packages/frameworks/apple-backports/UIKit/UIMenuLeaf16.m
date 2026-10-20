#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static id revenant_source_item(id sender)
{
    return [sender isKindOfClass:[UIView class]] || [sender isKindOfClass:[UIBarButtonItem class]] ? sender : nil;
}

@implementation UIAction (RevenantMenuLeaf16)

- (id)presentationSourceItem
{
    return revenant_source_item(self.sender);
}

- (void)performWithSender:(id)sender target:(id)target
{
    [self revenant_performWithSender:sender];
}

@end

@implementation UICommand (RevenantMenuLeaf16)

- (id)sender
{
    return objc_getAssociatedObject(self, @selector(sender));
}

- (id)presentationSourceItem
{
    return revenant_source_item(self.sender);
}

- (void)performWithSender:(id)sender target:(id)target
{
    [self revenant_performWithSender:sender target:target];
}

@end
