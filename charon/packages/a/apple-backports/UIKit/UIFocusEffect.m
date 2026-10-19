#import <UIKit/UIKit.h>
#import <objc/message.h>

// UIFocusEffect, iOS 15. The base effect is a plain object: a focus effect is drawn by the focus engine, which the port does not run, so an
// effect is kept and read back and nothing is drawn with it. The header makes -init and +new unavailable to the compiler, so the instance is
// made at run time with the NSObject initializer, as the host's own class answers it (measured by tests/backports/host/focus-effects). Copying
// an effect returns the effect itself, which the host does too.
@implementation UIFocusEffect

+ (instancetype)effect
{
    return ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)(self, @selector(alloc)), @selector(init));
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
