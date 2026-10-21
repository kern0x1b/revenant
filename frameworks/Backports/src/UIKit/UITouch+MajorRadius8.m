#import <UIKit/UIKit.h>
#import <objc/message.h>

@implementation UITouch (RevenantMajorRadius8)

- (CGFloat)majorRadius
{
    SEL radius = sel_registerName("_pathMajorRadius");
    if (![self respondsToSelector:radius])
        [NSException raise:NSInternalInconsistencyException format:@"-[UITouch majorRadius]: this system reports no touch radius"];
    return ((float (*)(id, SEL))objc_msgSend)(self, radius);
}

@end
