#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIWindowScene (CharonWindowing16)

// Nil on a platform without window behaviours, as the header says; a phone or tablet is one.
- (UISceneWindowingBehaviors *)windowingBehaviors
{
    return nil;
}

@end
