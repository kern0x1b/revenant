// intents12-rows.m: the twelve members of the iOS 12.0 group that the generator writes by hand
// (gen-intents.py's EXTRA_METHODS), measured against the system's own Intents.
//
// WHAT THIS ANSWERS, PER MEMBER:
//
//   class_getMethodImplementation / class_getClassMethod   the selector has an implementation
//   the call itself                                            what the framework does with it
//   for the three members that take a completion handler      whether the handler runs before the
//                                                             call returns, and whether it runs at
//                                                             all inside a bounded run loop
//
// WHY objc_msgSend AND NOT THE IMP FOR THE CALL.  factory-rows.m, in this same directory, records
// the measured reason: this host's Intents compiles its Objective-C entry points as SVE and
// pointer-authenticated thunks, so a bare C function pointer reaches them on the wrong convention
// and the process dies with EXC_ARM_DA_ALIGN.  objc_msgSend is the runtime's own entry point and
// dispatches on the real convention, so every call below goes through it.  The IMP is READ and never
// CALLED: presence is the question the presence read answers, and calling it is the question the
// call answers.  A Method is read out with method_getImplementation and not assigned straight to an
// IMP: class_getClassMethod answers a Method, and a Method is not an implementation.
//
// WHY EVERY CLASS AND EVERY SELECTOR IS A STRING HERE.  Two of the five classes are
// API_UNAVAILABLE(macos) in this SDK's own headers -
//
//   INRelevantShortcutStore.h:18  API_AVAILABLE(ios(12.0), watchos(5.0)) API_UNAVAILABLE(macos)
//   INUpcomingMediaManager.h:18  API_AVAILABLE(ios(12.0), watchos(5.0)) API_UNAVAILABLE(macos, tvos)
//
// so a variable of either class's own type does not compile in this program and the two enumerations
// -setPredictionMode:forType: takes cannot be named either.  Every class is NSClassFromString, every
// selector is NSSelectorFromString or a @selector on a member of NSObject, and the two enumeration
// arguments are their own types' declared zero cases (0 is INUpcomingMediaPredictionModeDefault and
// 0 is INMediaItemTypeUnknown), not numbers picked for this probe.  What is read is the framework's
// own object.
//
// WHY ONE SECTION PER RUN.  The section is an argument, so a member whose call kills the process or
// waits for ever cannot take the other eleven down with it, and the run always prints what it
// measured for the rest.  factory-rows.m records the same decision for the same reason.
//
// THE CONTROL IS IN EVERY RUN, and it is two questions.  A class the system does not carry must read
// ABSENT, or a harness that measured nothing is indistinguishable from one that measured an answer;
// and NSObject - a class whose header marks nothing unavailable - must answer, or a run where every
// call died is a run that printed nothing and said green.
//
//   $ xcrun clang -fobjc-arc -w -framework Intents -framework Foundation \
//         tests/backports/host/intents/intents12-rows.m -o intents12-rows
//   $ ./intents12-rows defaultStore     # also: new-shortcut, new-voice, new-centre,
//                                        #       sharedManager, sharedCenter,
//                                        #       setRelevantShortcuts, getAllVoiceShortcuts,
//                                        #       getVoiceShortcut, setShortcutSuggestions,
//                                        #       setSuggestedMediaIntents, setPredictionMode
//
// WHAT THIS DOES NOT ANSWER, and it is the whole of the limit: nothing here runs the port's own
// objects.  The port's classes and the framework's share a name, so a lookup in one process returns
// the framework's object; reaching the port's implementations needs tests/backports/host/
// prefix_selectors.py, and facts/Intents/Intents.md names that as owed.  What is measured here is
// what the system's own framework does with these twelve, which is the oracle the port's rows have
// to be able to answer for.
#import <Foundation/Foundation.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <unistd.h>

// One wrapper per arity, so each call names its own signature.  A single variadic helper forwarding
// a va_list would be shorter and wrong: a va_list is not a set of arguments.
static id send_none(id receiver, SEL selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
}

static void send_one_object(id receiver, SEL selector, id first)
{
    ((void (*)(id, SEL, id))objc_msgSend)(receiver, selector, first);
}

static void send_two_integers(id receiver, SEL selector, NSInteger first, NSInteger second)
{
    ((void (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(receiver, selector, first, second);
}

/// The IMP of a class method, read out of the Method rather than assigned from it.
static IMP classImp(Class cls, SEL selector)
{
    Method found = cls ? class_getClassMethod(cls, selector) : NULL;
    return found ? method_getImplementation(found) : NULL;
}

static IMP instanceImp(Class cls, SEL selector)
{
    return cls ? class_getMethodImplementation(cls, selector) : NULL;
}

static Class named(const char *name)
{
    return NSClassFromString([NSString stringWithUTF8String:name]);
}

/// How long a handler is given to run, and how it is read.  A handler that runs before the call
/// returns is a synchronous answer; one that runs inside the window after it is an asynchronous one;
/// one that never runs is the third thing, and the only way to tell it from the second is to wait.
/// `detail` is read after the window, so the values the handler wrote are the ones it wrote last.
static const NSTimeInterval HANDLER_WINDOW = 5.0;

/* The handler's own answer, printed beside the timing.  One buffer for the whole program, and it is
   cleared before every call, so a handler that never runs prints nothing rather than the last
   handler's values. */
static char buffer[256];

/* WHICH THREAD, and whether any run loop was needed, because those two are what the port's own
   answer is chosen from and neither may be assumed: the port dispatches to the default global
   queue, and the only reason that is the queue to choose is that the framework's handler is likewise
   not the caller's thread and likewise needs no run loop.  noRunLoop is 1 when the handler fired
   while this process sat in usleep with no run loop turning anywhere - which a main-queue handler
   could not manage, because nothing would be running the main run loop. */
static volatile int handlerOnMainThread = -1;

/* The assertion the port's own three bodies are held to, counted and exited on. */
static int failures = 0;

static void reportHandler(const char *row, volatile int *ran, const char *detail)
{
    int beforeReturn = *ran;
    /* Half the window is spent with NO run loop turning at all, so "fired anyway" and "fired because
       a run loop turned" are two different answers instead of one, and a main-queue handler is still
       given its half rather than being written off. */
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:HANDLER_WINDOW];
    while (!*ran && [limit timeIntervalSinceNow] > HANDLER_WINDOW / 2) {
        usleep(50000);
    }
    int withoutRunLoop = *ran;
    while (!*ran && [limit timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    }
    printf("intents12 %-58s handler before-return=%d within-%.0fs=%d on-main-thread=%d "
           "no-run-loop=%d %s\n", row, beforeReturn, HANDLER_WINDOW, *ran, handlerOnMainThread,
           withoutRunLoop, detail);
    /* THE ASSERTION: a handler called before the method returned is a different answer from one
       called after it, and a caller that sets state after the call and reads it in the handler
       breaks on the synchronous one only. The process exits non-zero, so run-rows.sh cannot report
       green over it. Asserted on the receiver this section was asked about, which is the singleton:
       a fresh instance is measured as well and is deliberately not asserted, because the host
       answers that one in ways this run does not promise (measureHandlerMember's own comment). */
    if (beforeReturn) {
        printf("intents12 %-58s FAIL the handler ran BEFORE the method returned\n", row);
        failures++;
    }
}

/// One member that is a class method taking nothing and returning the object.
static void measureFactory(const char *row, const char *className, SEL selector, BOOL singletonTwice)
{
    Class cls = named(className);
    if (!cls) { printf("intents12 %-58s ABSENT class=%s\n", row, className); return; }
    IMP imp = classImp(cls, selector);
    if (!imp) { printf("intents12 %-58s IMP NULL\n", row); return; }
    id first = send_none(cls, selector);
    if (!first) {
        printf("intents12 %-58s IMP non-NULL returned nil\n", row);
        return;
    }
    if (singletonTwice) {
        id second = send_none(cls, selector);
        printf("intents12 %-58s IMP non-NULL returned %s identical=%d\n", row,
               class_getName([first class]), first && second ? (int)(first == second) : -1);
    } else {
        printf("intents12 %-58s IMP non-NULL returned %s\n", row, class_getName([first class]));
    }
}

/// The receiver a row is asked about: the singleton the header's own @note names where the class
/// has one, and a freshly allocated and initialised one where it does not, which is the only other
/// receiver a caller can reach on a class whose -init is marked unavailable.
static id receiverFor(Class cls, SEL accessor)
{
    if (accessor) {
        return send_none(cls, accessor);
    }
    return send_none(send_none(cls, @selector(alloc)), @selector(init));
}

/// One member that is an instance method taking one object and answering nothing.
static void measureVoidSetter(const char *row, const char *className, SEL accessor, SEL selector,
                              id argument)
{
    Class cls = named(className);
    if (!cls) { printf("intents12 %-58s ABSENT class=%s\n", row, className); return; }
    id receiver = receiverFor(cls, accessor);
    if (!receiver) { printf("intents12 %-58s no receiver\n", row); return; }
    IMP imp = instanceImp(cls, selector);
    if (!imp) { printf("intents12 %-58s IMP NULL\n", row); return; }
    send_one_object(receiver, selector, argument);
    printf("intents12 %-58s receiver=%s IMP non-NULL returned void\n", row,
           class_getName([receiver class]));
}

/// One member that is an instance method taking two enumerations and answering nothing.
static void measurePredictionMode(const char *row, const char *className, SEL accessor)
{
    Class cls = named(className);
    if (!cls) { printf("intents12 %-58s ABSENT class=%s\n", row, className); return; }
    id receiver = receiverFor(cls, accessor);
    if (!receiver) { printf("intents12 %-58s no receiver\n", row); return; }
    IMP imp = instanceImp(cls, NSSelectorFromString(@"setPredictionMode:forType:"));
    if (!imp) { printf("intents12 %-58s IMP NULL\n", row); return; }
    /* Each argument is its own enumeration's declared zero case, not a number picked for this probe:
       INUpcomingMediaManager.h:14 gives INUpcomingMediaPredictionModeDefault = 0 and
       INMediaItemType.h:15 gives INMediaItemTypeUnknown = 0. */
    send_two_integers(receiver, NSSelectorFromString(@"setPredictionMode:forType:"), 0, 0);
    printf("intents12 %-58s receiver=%s IMP non-NULL returned void mode=0 type=0\n", row,
           class_getName([receiver class]));
}

/* The three members that take a completion handler.  The RECEIVER IS AN ARGUMENT and not a loop,
   and the reason is measured rather than tidiness: a version that asked both receivers in one
   process printed, for the same member and the same two calls, a synchronous handler for
   -getAllVoiceShortcutsWithCompletion: on a fresh instance in one run and an asynchronous one in
   the next.  The first call's work was still in flight when the second was made, so one process
   cannot measure two receivers and call both of them measured.  One process per receiver, and
   run-rows.sh starts one per row.
     ./intents12-rows getAllVoiceShortcuts singleton
     ./intents12-rows getAllVoiceShortcuts fresh
   The singleton is the receiver the header's @note names and the one an application sends to; a
   fresh instance is there because a class whose -init is marked unavailable is one an application
   never holds, so the two are not interchangeable and the difference is worth seeing. */
static void measureHandlerMember(const char *row, const char *className, SEL accessor, BOOL singleton,
                                 SEL selector, void (^send)(id receiver, volatile int *ran))
{
    const char *which = singleton ? "the singleton" : "a fresh instance";
    Class cls = named(className);
    if (!cls) {
        printf("intents12 %-46s on %-16s ABSENT class=%s\n", row, which, className);
        return;
    }
    IMP imp = instanceImp(cls, selector);
    if (!imp) {
        printf("intents12 %-46s on %-16s IMP NULL\n", row, which);
        return;
    }
    id receiver = receiverFor(cls, singleton ? accessor : NULL);
    if (!receiver) {
        printf("intents12 %-46s on %-16s no receiver\n", row, which);
        return;
    }
    volatile int ran = 0;
    buffer[0] = '\0';
    handlerOnMainThread = -1;
    send(receiver, &ran);
    char rowName[160];
    snprintf(rowName, sizeof rowName, "%s on %s", row, which);
    reportHandler(rowName, &ran, buffer);
}

static void measureVoiceShortcuts(const char *row, BOOL singleton)
{
    measureHandlerMember(row, "INVoiceShortcutCenter", NSSelectorFromString(@"sharedCenter"), singleton,
        @selector(getAllVoiceShortcutsWithCompletion:), ^(id receiver, volatile int *ran) {
            ((void (*)(id, SEL, id))objc_msgSend)(receiver,
                @selector(getAllVoiceShortcutsWithCompletion:),
                ^(NSArray<INVoiceShortcut *> *found, NSError *error) {
                    *ran = 1;
                    handlerOnMainThread = [NSThread isMainThread] ? 1 : 0;
                    snprintf(buffer, sizeof buffer, "count=%lu array-nil=%d error=%s",
                             (unsigned long)found.count, found == nil, error ? "non-nil" : "nil");
                });
        });
}

static void measureOneVoiceShortcut(const char *row, BOOL singleton)
{
    measureHandlerMember(row, "INVoiceShortcutCenter", NSSelectorFromString(@"sharedCenter"), singleton,
        @selector(getVoiceShortcutWithIdentifier:completion:), ^(id receiver, volatile int *ran) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(receiver,
                @selector(getVoiceShortcutWithIdentifier:completion:), [NSUUID UUID],
                ^(INVoiceShortcut *found, NSError *error) {
                    *ran = 1;
                    handlerOnMainThread = [NSThread isMainThread] ? 1 : 0;
                    snprintf(buffer, sizeof buffer, "shortcut=%s error=%s",
                             found ? "an object" : "nil", error ? "non-nil" : "nil");
                });
        });
}

static void measureRelevantShortcuts(const char *row, BOOL singleton)
{
    measureHandlerMember(row, "INRelevantShortcutStore", NSSelectorFromString(@"defaultStore"), singleton,
        @selector(setRelevantShortcuts:completionHandler:), ^(id receiver, volatile int *ran) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(receiver,
                @selector(setRelevantShortcuts:completionHandler:), [NSArray array],
                ^(NSError *error) {
                    *ran = 1;
                    handlerOnMainThread = [NSThread isMainThread] ? 1 : 0;
                    snprintf(buffer, sizeof buffer, "error=%s", error ? "non-nil" : "nil");
                });
        });
}

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: intents12-rows SECTION [singleton|fresh]\n"); return 64; }
    const char *section = argv[1];
    /* The receiver of the three handler members.  It is an argument because one process cannot
       measure both: measureHandlerMember's own comment gives the measurement that showed it. */
    BOOL singleton = YES;
    if (argc > 2) {
        if (!strcmp(argv[2], "fresh")) {
            singleton = NO;
        } else if (strcmp(argv[2], "singleton")) {
            fprintf(stderr, "intents12-rows: the receiver is singleton or fresh, not: %s\n", argv[2]);
            return 64;
        }
    }

    /* The control, in every run: the classes the system must carry, and the one it must not. */
    if (!strcmp(section, "classes")) {
        printf("intents12 classes INShortcut=%d INVoiceShortcut=%d INVoiceShortcutCenter=%d "
               "INRelevantShortcutStore=%d INUpcomingMediaManager=%d INObject=%d "
               "INCharonNoSuchClassForThisHarness=%d\n",
               named("INShortcut") != NULL, named("INVoiceShortcut") != NULL,
               named("INVoiceShortcutCenter") != NULL, named("INRelevantShortcutStore") != NULL,
               named("INUpcomingMediaManager") != NULL, named("INObject") != NULL,
               named("INCharonNoSuchClassForThisHarness") != NULL);
        return 0;
    }
    /* The negative control: a member of a class the system does not carry must read ABSENT. */
    if (!strcmp(section, "absent-control")) {
        measureFactory("+[INCharonNoSuchClassForThisHarness sharedCenter]", "INCharonNoSuchClassForThisHarness",
                       NSSelectorFromString(@"sharedCenter"), NO);
        return 0;
    }
    /* The positive control: a class whose header marks nothing unavailable must answer. */
    if (!strcmp(section, "object-control")) {
        measureFactory("+[NSObject new]", "NSObject", @selector(new), NO);
        return 0;
    }

    /* The negative control FOR THE ASSERTION, not for the reader.  It performs a synchronous call -
       a handler invoked inline, before its method returns - through the same reportHandler, so a
       check that had stopped failing on before-return=1 would pass this section and be caught here
       instead. It reads INTENTS, which is the framework's own, and touches nothing of the twelve. */
    if (!strcmp(section, "sync-plant")) {
        static char planted[256];
        static volatile int ran = 0;
        handlerOnMainThread = -1;
        snprintf(planted, sizeof planted, "%s", "a handler called inline");
        ((void (^)(void))^{
            ran = 1;
            handlerOnMainThread = 1;
        })();
        reportHandler("the plant: a synchronous answer", &ran, planted);
        return failures ? 1 : 0;
    }

    if (!strcmp(section, "new-shortcut")) {
        measureFactory("+[INShortcut new]", "INShortcut", @selector(new), NO);
    } else if (!strcmp(section, "new-voice")) {
        measureFactory("+[INVoiceShortcut new]", "INVoiceShortcut", @selector(new), NO);
    } else if (!strcmp(section, "new-centre")) {
        measureFactory("+[INVoiceShortcutCenter new]", "INVoiceShortcutCenter", @selector(new), NO);
    } else if (!strcmp(section, "defaultStore")) {
        measureFactory("+[INRelevantShortcutStore defaultStore]", "INRelevantShortcutStore",
                       NSSelectorFromString(@"defaultStore"), YES);
    } else if (!strcmp(section, "sharedManager")) {
        measureFactory("+[INUpcomingMediaManager sharedManager]", "INUpcomingMediaManager",
                       NSSelectorFromString(@"sharedManager"), YES);
    } else if (!strcmp(section, "sharedCenter")) {
        measureFactory("+[INVoiceShortcutCenter sharedCenter]", "INVoiceShortcutCenter",
                       NSSelectorFromString(@"sharedCenter"), YES);
    } else if (!strcmp(section, "setRelevantShortcuts")) {
        measureRelevantShortcuts("-[INRelevantShortcutStore setRelevantShortcuts:completionHandler:]",
                                 singleton);
    } else if (!strcmp(section, "getAllVoiceShortcuts")) {
        measureVoiceShortcuts("-[INVoiceShortcutCenter getAllVoiceShortcutsWithCompletion:]", singleton);
    } else if (!strcmp(section, "getVoiceShortcut")) {
        measureOneVoiceShortcut("-[INVoiceShortcutCenter getVoiceShortcutWithIdentifier:completion:]",
                                singleton);
    } else if (!strcmp(section, "setShortcutSuggestions")) {
        measureVoidSetter("-[INVoiceShortcutCenter setShortcutSuggestions:]", "INVoiceShortcutCenter",
                          NSSelectorFromString(@"sharedCenter"),
                          NSSelectorFromString(@"setShortcutSuggestions:"), [NSArray array]);
    } else if (!strcmp(section, "setSuggestedMediaIntents")) {
        measureVoidSetter("-[INUpcomingMediaManager setSuggestedMediaIntents:]", "INUpcomingMediaManager",
                          NSSelectorFromString(@"sharedManager"),
                          NSSelectorFromString(@"setSuggestedMediaIntents:"), [NSOrderedSet orderedSet]);
    } else if (!strcmp(section, "setPredictionMode")) {
        measurePredictionMode("-[INUpcomingMediaManager setPredictionMode:forType:]",
                              "INUpcomingMediaManager", NSSelectorFromString(@"sharedManager"));
    } else {
        fprintf(stderr, "intents12-rows: no such section: %s\n", section);
        return 65;
    }
    /* The exit status is the verdict.  A run that found a handler called before its method returned
       says so on stdout and here, so run-rows.sh cannot print green over it. */
    return failures ? 1 : 0;
}
