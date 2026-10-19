#import <Foundation/Foundation.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <unistd.h>

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

static const NSTimeInterval HANDLER_WINDOW = 5.0;

static char buffer[256];

static volatile int handlerOnMainThread = -1;

static int failures = 0;

static void reportHandler(const char *row, volatile int *ran, const char *detail)
{
    int beforeReturn = *ran;
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
    if (beforeReturn) {
        printf("intents12 %-58s FAIL the handler ran BEFORE the method returned\n", row);
        failures++;
    }
}

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

static id receiverFor(Class cls, SEL accessor)
{
    if (accessor) {
        return send_none(cls, accessor);
    }
    return send_none(send_none(cls, @selector(alloc)), @selector(init));
}

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

static void measurePredictionMode(const char *row, const char *className, SEL accessor)
{
    Class cls = named(className);
    if (!cls) { printf("intents12 %-58s ABSENT class=%s\n", row, className); return; }
    id receiver = receiverFor(cls, accessor);
    if (!receiver) { printf("intents12 %-58s no receiver\n", row); return; }
    IMP imp = instanceImp(cls, NSSelectorFromString(@"setPredictionMode:forType:"));
    if (!imp) { printf("intents12 %-58s IMP NULL\n", row); return; }
    send_two_integers(receiver, NSSelectorFromString(@"setPredictionMode:forType:"), 0, 0);
    printf("intents12 %-58s receiver=%s IMP non-NULL returned void mode=0 type=0\n", row,
           class_getName([receiver class]));
}

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
    BOOL singleton = YES;
    if (argc > 2) {
        if (!strcmp(argv[2], "fresh")) {
            singleton = NO;
        } else if (strcmp(argv[2], "singleton")) {
            fprintf(stderr, "intents12-rows: the receiver is singleton or fresh, not: %s\n", argv[2]);
            return 64;
        }
    }

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
    if (!strcmp(section, "absent-control")) {
        measureFactory("+[INCharonNoSuchClassForThisHarness sharedCenter]", "INCharonNoSuchClassForThisHarness",
                       NSSelectorFromString(@"sharedCenter"), NO);
        return 0;
    }
    if (!strcmp(section, "object-control")) {
        measureFactory("+[NSObject new]", "NSObject", @selector(new), NO);
        return 0;
    }

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
    return failures ? 1 : 0;
}
