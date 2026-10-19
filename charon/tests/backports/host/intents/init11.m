// init11.m - the host's own -init for the sixteen iOS 11.0 Intents classes, measured class by class.
//
// Every one of these sixteen rows in registry/Intents/ios11.json is `implemented`, and the `source`
// of each one says the host had been measured on eight of the hundred and ten classes by hand and
// that "the other hundred and two are the same rule applied to the same header, which is a claim and
// not a measurement until that harness runs". This is that harness, for the sixteen this slice owns:
// one run, one line per class, and the answer for each class is read here rather than assumed.
//
// WHAT A LINE ASSERTS, and why each part is there:
//
//   present          objc_getClass is non-NULL. The release carries the name, so a zero on a line is
//                    the release's answer and not a reader that looked in the wrong image.
//   init non-NULL    class_getMethodImplementation(Cls, @selector(init)). This is how the header's
//                    NS_UNAVAILABLE is read: the marker forbids NAMING the selector at compile time
//                    and says nothing about whether the system answers one.
//   returns object   The call goes THROUGH that IMP and never by name, because a compile-time
//                    [[Cls alloc] init] is exactly what the marker forbids. An object and no
//                    @throw is the claim; nil and a SIGSEGV are measured answers too, and both are
//                    printed as such (see THE THREE HOST ANSWERS below).
//   responds         respondsToSelector:init is 1, which is the claim a caller dispatches on.
//   own properties   Every property the class declares ITSELF is read back through the object the
//                    IMP returned. A bare -init stores nothing, so an object property reads nil and a
//                    scalar reads 0, and anything else is not -init's answer.
//
// THREE DEFECTS MEASURED WHILE WRITING THIS, each of which had the check reporting the reader
// instead of the release, and each kept here because the next reader will hit them too:
//
//   1. class_copyPropertyList returns the INHERITED properties as well. hash, superclass, description
//      and debugDescription are never nil, so the first build printed "INCallRecord.hash is 0" and
//      made a line red for a reason that has nothing to do with -init. The fix is superclassDeclares,
//      and a property of a superclass is skipped rather than asserted.
//   2. "every property is nil" is FALSE for an enum or any other scalar: a bare -init cannot leave an
//      NSInteger property nil, it leaves it 0, and valueForKey: hands back an NSNumber(0). The eight
//      hand-measured classes carried no such property, which is why the claim survived them. The
//      check is the property's OWN declared type: an object type must be nil, anything else 0.
//   3. The receiver is an ALLOCATED INSTANCE. Passing the class object throws out of every line -
//      "+[INAddTasksIntentResponse initWithCode:userActivity:]: unrecognized selector sent to class" -
//      because class_getMethodImplementation finds an instance method. A class is not a receiver.
//
// And the reason every class is measured in a forked child: the system's own -init for these classes
// reaches intent machinery that only exists inside a real intent. Measured on this host,
// -[INCancelRideIntentResponse init] returns nil after the system logs "Unable to initialize
// 'INCancelRideIntentResponse'. Please make sure that your intent definition file is valid.", and
// the class after it takes the process down with SIGSEGV. A run that lets one class kill it reports
// nothing for the fifteen after it, so a child per class makes the crash a LINE - "crashed with
// signal 11" - which is the host's answer and not a lost run.
//
// THE CONTROL is the line the zeros are worthless without: the same run walks every class the process
// knows and prints how many begin IN, so a reader who sees a zero can see the run searched hundreds
// of names and the negative is the release's. The run before a control existed is why: 220 of 330
// lines were red with every port object linked in, because the port's class and the framework's were
// the same object.
//
// THE PLANT is the point. PLANTS=one-wrong makes one class report a property that is not zero, and
// that line must go red. A check that cannot fail guards nothing, and run-init11.sh runs that build
// too and fails when it does not - so "16 lines, 0 red" means the reader compared and agreed, not
// that the reader printed zeros.
//
//   xcrun clang -fobjc-arc -w init11.m -framework Intents -framework Foundation -o init11 && ./init11
//   PLANTS=one-wrong ./init11

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/wait.h>

// The sixteen classes registry/Intents/ios11.json carries a -[X init] row for. The list is here and
// is checked against the registry by run-init11.sh's fourth build, so a row the registry gains has to
// be a line this run prints: the harness is the MEASUREMENT FOR that registry, and a row with no
// line is a row nothing measures.
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

// The class the plant spoils: a real one from the list above, not a name invented for the plant, so
// the plant changes this class's answer and not the shape of the run.
static const char *PLANT_CLASS = "INBalanceAmount";

static BOOL gPlant;

// Every class the process knows, so the control is the size of the haystack this run searched.
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

// A property is this class's OWN when no superclass declares it. See defect 1 above.
static BOOL superclassDeclares(Class cls, const char *name)
{
    for (Class parent = class_getSuperclass(cls); parent; parent = class_getSuperclass(parent)) {
        if (class_getProperty(parent, name)) {
            return YES;
        }
    }
    return NO;
}

// The property's own declared type: an OBJECT type must read nil after a bare -init, and anything
// else must read 0, because a scalar cannot be nil. See defect 2 above.
static BOOL propertyIsObjectType(objc_property_t property)
{
    const char *attributes = property_getAttributes(property);
    const char *type = attributes ? strstr(attributes, "T") : NULL;
    if (!type) {
        return YES;
    }
    // "T@\"NSString\",C,N" for an object, "TQ" or "Ti" for a scalar; the quote may follow an @.
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
        // The plant: one class of the sixteen reports one property of its own that is not zero. It
        // has to be a property the class really declares, so it is the FIRST OWN property and not a
        // list index - an index would land on an inherited one after defect 1 was fixed.
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

// One class, in this process. The caller runs it in a forked child, because the host's own -init
// reaches intent machinery and can end the process; see the head of this file.
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
    // An allocated INSTANCE and never the class object: see defect 3.
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

// The child measures one class and _exits with its verdict; the parent turns the wait status into a
// line, so a class whose -init takes the process down is reported rather than losing the rest of the run.
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
        // Unbuffered: a child can die, and a redirected stdout is block buffered, so a crash in the
        // last class would lose every line before it.
        setvbuf(stdout, NULL, _IONBF, 0);
        gPlant = [[[NSProcessInfo processInfo] environment] objectForKey:@"PLANTS"] != nil;
        unsigned total = (unsigned)(sizeof(CLASSES) / sizeof(*CLASSES));
        NSUInteger control = controlCount();
        printf("intents-11 init, PLANTS=%s, %u classes, control: %lu names beginning IN found in "
               "this run\n", gPlant ? "one-wrong" : "(none)", total, (unsigned long)control);
        if (control < 100) {
            // A control this small means the reader is not seeing the framework at all, and every
            // line below would then be reporting the reader rather than the release.
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