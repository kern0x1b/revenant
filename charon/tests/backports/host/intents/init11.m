#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/wait.h>

static const char *CLASSES[] = {
    "INAddTasksIntentResponse",
    "INAppendToNoteIntentResponse",
    "INBalanceAmount",
    "INCallRecord",
    "INCancelRideIntent",
    "INCancelRideIntentResponse",
    "INCreateNoteIntentResponse",
    "INCreateTaskListIntentResponse",
    "INGetVisualCodeIntentResponse",
    "INRecurrenceRule",
    "INSearchForAccountsIntentResponse",
    "INSearchForNotebookItemsIntentResponse",
    "INSendRideFeedbackIntent",
    "INSendRideFeedbackIntentResponse",
    "INSetTaskAttributeIntentResponse",
    "INTransferMoneyIntentResponse",
};

static const char *PLANT_CLASS = "INBalanceAmount";

static BOOL gPlant;

static NSUInteger controlCount(void)
{
    unsigned count = objc_getClassList(NULL, 0);
    if (count == 0) {
        return 0;
    }
    Class *all = (Class *)malloc(sizeof(Class) * count);
    if (!all) {
        return 0;
    }
    count = objc_getClassList(all, count);
    NSUInteger found = 0;
    for (unsigned i = 0; i < count; i++) {
        const char *name = class_getName(all[i]);
        if (name && strncmp(name, "IN", 2) == 0) {
            found++;
        }
    }
    free(all);
    return found;
}

static BOOL superclassDeclares(Class cls, const char *name)
{
    for (Class parent = class_getSuperclass(cls); parent; parent = class_getSuperclass(parent)) {
        if (class_getProperty(parent, name)) {
            return YES;
        }
    }
    return NO;
}

static BOOL propertyIsObjectType(objc_property_t property)
{
    const char *attributes = property_getAttributes(property);
    const char *type = attributes ? strstr(attributes, "T") : NULL;
    if (!type) {
        return YES;
    }
    const char *p = type + 1;
    if (*p == '"') {
        p++;
    }
    return *p == '@';
}

static BOOL ownPropertiesAreZero(id object, Class cls, const char *name)
{
    unsigned count = 0;
    objc_property_t *list = class_copyPropertyList(cls, &count);
    if (!list) {
        return YES;
    }
    BOOL clean = YES, firstOwn = YES;
    for (unsigned i = 0; i < count; i++) {
        const char *property = property_getName(list[i]);
        if (!property || superclassDeclares(cls, property)) {
            continue;
        }
        BOOL isObject = propertyIsObjectType(list[i]);
        id value = [object valueForKey:[NSString stringWithUTF8String:property]];
        if (gPlant && !strcmp(name, PLANT_CLASS) && firstOwn) {
            value = isObject ? @"planted" : (id)@(42);
        }
        firstOwn = NO;
        if (isObject ? (value != nil) : (value == nil || ![value isEqual:@(0)])) {
            clean = NO;
            printf("    %s.%s is %s and a bare -init leaves an %s property at its zero\n",
                   name, property, [[value description] UTF8String],
                   isObject ? "object" : "scalar");
        }
    }
    free(list);
    return clean;
}

static int measureOne(const char *name)
{
    Class cls = objc_getClass(name);
    if (!cls) {
        printf("  %-34s ->  FAIL not present on this host\n", name);
        return 1;
    }
    SEL selector = @selector(init);
    IMP implementation = class_getMethodImplementation(cls, selector);
    if (!implementation) {
        printf("  %-34s ->  FAIL -init has no implementation\n", name);
        return 1;
    }
    id allocated = [cls alloc];
    if (!allocated) {
        printf("  %-34s ->  FAIL +alloc returned nil\n", name);
        return 1;
    }
    id object = nil;
    @try {
        object = ((id (*)(id, SEL))implementation)(allocated, selector);
    } @catch (NSException *thrown) {
        printf("  %-34s ->  FAIL -init through its IMP raised %s: %s\n",
               name, [[thrown name] UTF8String], [[thrown reason] UTF8String]);
        return 1;
    }
    if (!object) {
        printf("  %-34s ->  FAIL -init through its IMP returned nil\n", name);
        return 1;
    }
    if (![object isKindOfClass:cls]) {
        printf("  %-34s ->  FAIL -init through its IMP returned a %s\n",
               name, [object class] ? class_getName([object class]) : "foreign object");
        return 1;
    }
    if (![object respondsToSelector:selector]) {
        printf("  %-34s ->  FAIL respondsToSelector:init is 0\n", name);
        return 1;
    }
    if (!ownPropertiesAreZero(object, cls, name)) {
        printf("  %-34s ->  FAIL a property of its own is not at its zero\n", name);
        return 1;
    }
    printf("  %-34s ->  ok   IMP non-NULL, object returned, no exception, "
           "respondsToSelector:init 1, every own property at its zero\n", name);
    return 0;
}

static int measureForked(const char *name)
{
    fflush(stdout);
    pid_t child = fork();
    if (child < 0) {
        printf("  %-34s ->  FAIL fork failed: %s\n", name, strerror(errno));
        return 1;
    }
    if (child == 0) {
        int verdict = 0;
        @autoreleasepool {
            verdict = measureOne(name);
        }
        fflush(stdout);
        _exit(verdict);
    }
    int status = 0;
    while (waitpid(child, &status, 0) < 0 && errno == EINTR) {
    }
    if (WIFSIGNALED(status)) {
        printf("  %-34s ->  FAIL the system's own -init crashed this process with signal %d\n",
               name, WTERMSIG(status));
        return 1;
    }
    if (!WIFEXITED(status)) {
        printf("  %-34s ->  FAIL the child ended with wait status 0x%x\n", name, status);
        return 1;
    }
    return WEXITSTATUS(status) ? 1 : 0;
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        gPlant = [[[NSProcessInfo processInfo] environment] objectForKey:@"PLANTS"] != nil;
        unsigned total = (unsigned)(sizeof(CLASSES) / sizeof(*CLASSES));
        NSUInteger control = controlCount();
        printf("intents-11 init, PLANTS=%s, %u classes, control: %lu names beginning IN found in "
               "this run\n", gPlant ? "one-wrong" : "(none)", total, (unsigned long)control);
        if (control < 100) {
            printf("  intents-11 init: FAIL the control found only %lu IN names, so a zero above "
                   "would be the reader and not the release\n", (unsigned long)control);
            return 1;
        }
        NSUInteger red = 0;
        for (unsigned i = 0; i < total; i++) {
            red += (NSUInteger)measureForked(CLASSES[i]);
        }
        printf("intents-11 init: %u lines, %lu red\n", total, (unsigned long)red);
        if (gPlant && red == 0) {
            printf("  intents-11 init: FAIL the plant passed, so the check cannot fail\n");
            return 1;
        }
        printf("intents-11 init: %s\n", red ? "FAIL" : "PASS");
        return red ? 1 : 0;
    }
}
