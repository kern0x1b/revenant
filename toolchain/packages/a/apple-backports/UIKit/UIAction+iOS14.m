#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIAction (CharonFourteen)

+ (instancetype)actionWithHandler:(UIActionHandler)handler
{
    return [[self alloc] initCharonWithTitle:@"" image:nil identifier:nil handler:handler];
}

- (id)sender
{
    return objc_getAssociatedObject(self, @selector(sender));
}

@end
