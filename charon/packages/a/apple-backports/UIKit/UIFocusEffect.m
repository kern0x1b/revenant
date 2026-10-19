#import <UIKit/UIKit.h>
#import <objc/message.h>

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
