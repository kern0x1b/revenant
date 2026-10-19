#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

static const char *CONTROLS[] = { "NSObject", "NSString", "INCar", "INListCarsIntent" };

static void where(const char *label, IMP imp)
{
    Dl_info info;
    memset(&info, 0, sizeof info);
    const char *image = "(none)";
    const char *symbol = "(none)";
    if (imp && dladdr((const void *)imp, &info) && info.dli_fname) {
        image = info.dli_fname;
        symbol = info.dli_sname ? info.dli_sname : "(no symbol)";
    }
    printf("  %-48s %-16s %-52s %s\n", label, imp ? "an IMP" : "(none)", symbol, image);
}

int main(void)
{
    @autoreleasepool {
        int missing = 0;
        printf("provenance: the control, and what a zero looks like when it is real\n");

        printf("control, %zu classes a blind reader would miss or invent:\n",
               sizeof(CONTROLS) / sizeof(*CONTROLS));
        for (size_t i = 0; i < sizeof(CONTROLS) / sizeof(*CONTROLS); i++) {
            Class cls = NSClassFromString(@(CONTROLS[i]));
            if (!cls) missing++;
            printf("  %-48s %s\n", CONTROLS[i], cls ? "found" : "NOT FOUND");
        }
        if (missing) {
            printf("provenance: FAIL %d control classes not found, so a zero elsewhere is the reader's\n",
                   missing);
            return 1;
        }

        printf("\nthe forwarding trampoline, and three selectors beside it:\n");
        {
            Class attachment = NSClassFromString(@"INSendMessageAttachment");
            Class car = NSClassFromString(@"INCar");
            Class list = NSClassFromString(@"INListCarsIntent");

            where("+[INSendMessageAttachment noSuchSelector:]",
                  class_getMethodImplementation(object_getClass(attachment),
                                                NSSelectorFromString(@"noSuchSelector:")));
            where("+[INSendMessageAttachment attachmentWithAudioMessageFile:]",
                  class_getMethodImplementation(object_getClass(attachment),
                                                @selector(attachmentWithAudioMessageFile:)));
            where("-[INCar setMaximumPower:forChargingConnectorType:]",
                  method_getImplementation(class_getInstanceMethod(
                      car, @selector(setMaximumPower:forChargingConnectorType:))));
            where("-[INListCarsIntent init]",
                  method_getImplementation(class_getInstanceMethod(list, @selector(init))));
        }

        printf("provenance: ->  PASS every control found, so an absent class is the host's own\n");
        return 0;
    }
}
