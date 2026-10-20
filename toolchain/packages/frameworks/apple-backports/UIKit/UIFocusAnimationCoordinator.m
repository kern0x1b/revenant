#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIFocusAnimationCoordinator

- (void)addCoordinatedAnimations:(void (^)(void))animations completion:(void (^)(void))completion
{
    if (animations)
        animations();
    if (completion)
        completion();
}

@end
