#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIAction (RevenantFourteen)

+ (instancetype)actionWithHandler:(UIActionHandler)handler
{
    return [[self alloc] initRevenantWithTitle:@"" image:nil identifier:nil handler:handler];
}

- (id)sender
{
    return objc_getAssociatedObject(self, @selector(sender));
}

@end
