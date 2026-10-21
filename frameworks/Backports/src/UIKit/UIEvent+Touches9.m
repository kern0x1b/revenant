#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIEvent (RevenantTouches9)

- (NSArray<UITouch *> *)coalescedTouchesForTouch:(UITouch *)touch
{
    return touch ? @[touch] : nil;
}

- (NSArray<UITouch *> *)predictedTouchesForTouch:(UITouch *)touch
{
    return nil;
}

@end
