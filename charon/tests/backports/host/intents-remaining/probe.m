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
        class_method("INIntentResolutionResult", "unsupported", "control: declared in the 16.4 header");
        class_method("INIntentResolutionResult", "needsValue", "control: declared in the 16.4 header");
        instance_method("INRideDriver", "initWithPhoneNumber:nameComponents:displayName:image:rating:", "control: declared");
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
