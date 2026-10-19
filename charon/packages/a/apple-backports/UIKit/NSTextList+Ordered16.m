#import <UIKit/UIKit.h>
#import <objc/message.h>

// -[NSTextList isOrdered], iOS 16.0.
//
// NSTextList.h:55 declares it as
//
//     @property (readonly, getter=isOrdered) BOOL ordered API_AVAILABLE(ios(16.0))
//
// so the selector is isOrdered and `ordered` is not one: the property name and the getter are two
// different strings and only the getter exists. The release already computes the answer and has
// since well before 16.0 - its NSTextList carries a private -_isOrdered at both band ends - so this
// asks the release's own method rather than keeping a second copy of a value it already has. There is
// no public mechanism below 16.0 (measured: the 6.1.3 and 12.0 inventories hold no isOrdered, no
// ordered and no other public spelling of the property), which is why the private one is the answer;
// the measurement is in facts/UIKit/TextListOrdered16.md.

@implementation NSTextList (CharonOrdered16)

- (BOOL)isOrdered
{
    SEL release = NSSelectorFromString(@"_isOrdered");
    if (![self respondsToSelector:release])
        return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(self, release);
}

@end