#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UISceneWindowingBehaviors (RevenantGetter16)

- (BOOL)closable
{
    return [self isClosable];
}

- (BOOL)miniaturizable
{
    return [self isMiniaturizable];
}

@end
