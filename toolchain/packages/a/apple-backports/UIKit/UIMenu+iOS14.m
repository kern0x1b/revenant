#import "RevenantMenus.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIMenu (RevenantFourteen)

+ (UIMenu *)menuWithChildren:(NSArray<UIMenuElement *> *)children
{
    return [[self alloc] initRevenantWithTitle:@"" image:nil identifier:nil options:0 children:children];
}

@end
