#import "CharonMenus.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIMenu (CharonFourteen)

+ (UIMenu *)menuWithChildren:(NSArray<UIMenuElement *> *)children
{
    return [[self alloc] initCharonWithTitle:@"" image:nil identifier:nil options:0 children:children];
}

@end
