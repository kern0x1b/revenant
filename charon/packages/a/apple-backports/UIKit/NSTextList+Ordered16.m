#import <UIKit/UIKit.h>
#import <objc/message.h>

@implementation NSTextList (CharonOrdered16)

- (BOOL)isOrdered
{
    SEL release = NSSelectorFromString(@"_isOrdered");
    if (![self respondsToSelector:release])
        return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(self, release);
}

@end
