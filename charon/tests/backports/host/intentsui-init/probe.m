// probe.m - what the host's IntentsUI answers for the six initialisers the rows of IntentsUI's 12.0 group name, and what
// the port answers for the same six, from one source compiled twice by run.sh.
//
// The six rows: -[INUIAddVoiceShortcutButton initWithFrame:] and -[INUIAddVoiceShortcutButton init], the same two
// for INUIAddVoiceShortcutViewController and INUIEditVoiceShortcutViewController, with initWithNibName:bundle: for
// the two view controllers in place of initWithFrame:. Each is called through objc_msgSend, not by a compile-time
// send, because the headers mark some of them NS_UNAVAILABLE and the measurement is what the runtime does.
//
// Each line is one row: the class the answer is (or nil), whether it is an instance of the class the row names, and
// whether the answer's own class is the row's class (not a superclass). The port's classes are named with the
// CharonHost prefix that run.sh renames them to, and the printed name is Apple's.
//
// Nothing here depends on the clock or on an address.
//
//   sh run.sh   (Catalyst only: the classes are UIKit subclasses, and macOS has no UIKit to subclass)
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <string.h>

#ifdef PORT
#define PREFIX "CharonHost"
#else
#define PREFIX ""
#endif

static const char *appleName(id object)
{
    const char *name = class_getName([object class]);
    size_t prefix = strlen(PREFIX);
    return strncmp(name, PREFIX, prefix) == 0 ? name + prefix : name;
}

static Class charonClass(const char *name)
{
    return NSClassFromString([NSString stringWithFormat:@"%s%s", PREFIX, name]);
}

static void row(const char *className, const char *selector, id answer, Class expected)
{
    if (!answer) {
        printf("%s\t%s\tnil\n", className, selector);
        return;
    }
    printf("%s\t%s\t%s\tisKind %d\texact %d\n", className, selector, appleName(answer),
           [answer isKindOfClass:expected] ? 1 : 0, [answer class] == expected ? 1 : 0);
}

int main(void)
{
    @autoreleasepool {
        Class button = charonClass("INUIAddVoiceShortcutButton");
        Class addVC = charonClass("INUIAddVoiceShortcutViewController");
        Class editVC = charonClass("INUIEditVoiceShortcutViewController");
        if (!button || !addVC || !editVC) {
            printf("FAIL: a class is not defined in this build\n");
            return 2;
        }

        // Every initialiser, called through its own selector's IMP on a fresh allocation.
        id buttonInit = ((id (*)(id, SEL))objc_msgSend)([button alloc], @selector(init));
        row("INUIAddVoiceShortcutButton", "init", buttonInit, button);
        id buttonFrame = ((id (*)(id, SEL, CGRect))objc_msgSend)([button alloc], @selector(initWithFrame:), CGRectZero);
        row("INUIAddVoiceShortcutButton", "initWithFrame:", buttonFrame, button);

        id addInit = ((id (*)(id, SEL))objc_msgSend)([addVC alloc], @selector(init));
        row("INUIAddVoiceShortcutViewController", "init", addInit, addVC);
        id addNib = ((id (*)(id, SEL, id, id))objc_msgSend)([addVC alloc], @selector(initWithNibName:bundle:), nil, nil);
        row("INUIAddVoiceShortcutViewController", "initWithNibName:bundle:", addNib, addVC);

        id editInit = ((id (*)(id, SEL))objc_msgSend)([editVC alloc], @selector(init));
        row("INUIEditVoiceShortcutViewController", "init", editInit, editVC);
        id editNib = ((id (*)(id, SEL, id, id))objc_msgSend)([editVC alloc], @selector(initWithNibName:bundle:), nil, nil);
        row("INUIEditVoiceShortcutViewController", "initWithNibName:bundle:", editNib, editVC);
    }
    return 0;
}
