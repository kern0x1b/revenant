#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CharonButtonTint : NSObject
@end

@implementation CharonButtonTint

+ (void)load
{
    if ([UIImage instancesRespondToSelector:@selector(imageWithRenderingMode:)])
        return;
    Class button = [UIButton class];
    SEL setter = @selector(setTintColor:);
    Method native = class_getInstanceMethod(button, setter);
    if (!native)
        return;
    void (*original)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(native);
    class_replaceMethod(button, setter, imp_implementationWithBlock(^(UIButton *self_, UIColor *color) {
        if ([UIView instancesRespondToSelector:setter]) {
            void (*hierarchy)(id, SEL, id) = (void (*)(id, SEL, id))class_getMethodImplementation([UIView class], setter);
            if (hierarchy != original)
                hierarchy(self_, setter, color);
        }
        original(self_, setter, color);
    }), method_getTypeEncoding(native));
}

@end
