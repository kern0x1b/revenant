#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIFocusSystem

+ (UIFocusSystem *)focusSystemForEnvironment:(id<UIFocusEnvironment>)environment
{
    return nil;
}

+ (BOOL)environment:(id<UIFocusEnvironment>)environment containsEnvironment:(id<UIFocusEnvironment>)otherEnvironment
{
    id<UIFocusEnvironment> current = otherEnvironment;
    for (NSUInteger depth = 0; current && depth < 4096; depth++) {
        if (current == environment)
            return YES;
        current = current.parentFocusEnvironment;
    }
    return NO;
}

- (id<UIFocusItem>)focusedItem
{
    return nil;
}

- (void)requestFocusUpdateToEnvironment:(id<UIFocusEnvironment>)environment
{
}

- (void)updateFocusIfNeeded
{
}

@end
