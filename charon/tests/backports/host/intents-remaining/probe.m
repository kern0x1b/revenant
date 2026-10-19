// probe.m - which of the remaining Intents members the host RUNTIME carries, and which the SDK header does not declare.
//
// Every lookup is by name at run time (NSClassFromString, NSSelectorFromString, NSProtocolFromString), so no member
// is named at compile time, and no header is needed to build it: a member the header omits is still asked for. The
// verdict is the runtime's own answer: respondsToSelector: for a class and its metaclass, and class_getInstanceMethod
// for an instance method, with the image the class came from. Controls are members the headers DO declare, so a zero
// elsewhere is not a blind reader's zero.
//
//   xcrun clang -fno-objc-arc -framework Foundation -framework Intents probe.m -o probe   (macOS host)
//   xcrun clang -fno-objc-arc -target arm64-apple-ios15.0-macabi -isysroot $(xcrun --show-sdk-path) \
//       -iframework $(xcrun --show-sdk-path)/System/iOSSupport/System/Library/Frameworks \
//       -framework Foundation -framework Intents probe.m -o probe-catalyst
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>

static void class_method(const char *cls, const char *sel, const char *note)
{
    Class c = NSClassFromString(@(cls));
    if (!c) {
        printf("%s\t+%s\tclass-absent\t%s\n", cls, sel, note);
        return;
    }
    BOOL answers = [c respondsToSelector:NSSelectorFromString(@(sel))];
    printf("%s\t+%s\t%s\t%s\n", cls, sel, answers ? "YES" : "NO", note);
}

static void instance_method(const char *cls, const char *sel, const char *note)
{
    Class c = NSClassFromString(@(cls));
    if (!c) {
        printf("%s\t-%s\tclass-absent\t%s\n", cls, sel, note);
        return;
    }
    Method m = class_getInstanceMethod(c, NSSelectorFromString(@(sel)));
    printf("%s\t-%s\t%s\t%s\n", cls, sel, m ? "YES" : "NO", note);
}

static void protocol(const char *name)
{
    Protocol *p = NSProtocolFromString(@(name));
    printf("protocol\t%s\t%s\t-\n", name, p ? "YES" : "NO");
}

int main(void)
{
    @autoreleasepool {
        // controls: declared by the headers
        class_method("INIntentResolutionResult", "unsupported", "control: declared in the 16.4 header");
        class_method("INIntentResolutionResult", "needsValue", "control: declared in the 16.4 header");
        instance_method("INRideDriver", "initWithPhoneNumber:nameComponents:displayName:image:rating:", "control: declared");
        // the rows that the headers do not declare
        class_method("INIntentResolutionResult", "unsupportedWithReason:", "row: owed");
        class_method("INIntentResolutionResult", "confirmationRequiredWithItemToConfirm:forReason:", "row: owed");
        class_method("INIntentResolutionResult", "unsupportedForReason:", "header name for the first row");
        class_method("INIntentResolutionResult", "confirmationRequiredWithValueToConfirm:", "header name, not a row");
        instance_method("INRideDriver", "initWithHandle:displayName:image:rating:phoneNumber:", "row: owed");
        instance_method("INRideDriver", "initWithHandle:nameComponents:image:rating:phoneNumber:", "row: owed");
        instance_method("INRideDriver", "initWithPersonHandle:nameComponents:displayName:image:rating:phoneNumber:", "row: implemented");
        class_method("INImage", "systemImageNamed:", "row: owed");
        instance_method("INDateComponentsRange", "initWithEKRecurrenceRule:", "row: owed");
        instance_method("INDateComponentsRange", "EKRecurrenceRule", "row: owed");
        protocol("INIntentSetImageKeyPath");
        protocol("_INIntentSetImageKeyPath");
        protocol("INIntentResolutionResult");
    }
    return 0;
}
