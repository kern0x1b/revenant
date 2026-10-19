#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <string.h>

#ifdef PORT
#define PREFIX "RevenantHost"
#else
#define PREFIX ""
#endif

static const char *appleName(id object)
{
    const char *name = class_getName([object class]);
    size_t prefix = strlen(PREFIX);
    return strncmp(name, PREFIX, prefix) == 0 ? name + prefix : name;
}

static Class revenantClass(const char *name)
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
        Class button = revenantClass("INUIAddVoiceShortcutButton");
        Class addVC = revenantClass("INUIAddVoiceShortcutViewController");
        Class editVC = revenantClass("INUIEditVoiceShortcutViewController");
        if (!button || !addVC || !editVC) {
            printf("FAIL: a class is not defined in this build\n");
            return 2;
        }

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
