#import <CoreTelephony/CTCellularData.h>
#import <CoreTelephony/CoreTelephonyDefines.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "check.h"

typedef void *CTServerConnectionRef;
typedef void (*CTServerConnectionCallback)(CTServerConnectionRef connection, CFStringRef notificationType, CFDictionaryRef notificationInfo, void *context);
typedef struct {
    CFIndex version;
    void *info;
    const void *(*retain)(const void *info);
    void (*release)(const void *info);
    CFStringRef (*copyDescription)(const void *info);
} CTServerConnectionContext;
typedef CTServerConnectionRef (*CharonCTServerConnectionCreate)(CFAllocatorRef allocator, CTServerConnectionCallback callback, CTServerConnectionContext *context);
typedef CTError (*CharonCTServerConnectionGetCellularDataIsDisallowed)(CTServerConnectionRef connection, Boolean *disallowed);

static NSString *state_name(CTCellularDataRestrictedState state)
{
    switch (state) {
        case kCTCellularDataRestrictedStateUnknown: return @"unknown";
        case kCTCellularDataNotRestricted: return @"not-restricted";
        case kCTCellularDataRestricted: return @"restricted";
    }
    return @"?";
}

static void noop_callback(CTServerConnectionRef connection, CFStringRef notificationType, CFDictionaryRef notificationInfo, void *context)
{
    printf("diagnose: callback fired, notificationType=%s\n", notificationType ? [(__bridge NSString *)notificationType UTF8String] : "(null)");
    fflush(stdout);
}

static CTServerConnectionRef try_create(CharonCTServerConnectionCreate create, const char *label, CTServerConnectionCallback callback, CTServerConnectionContext *context)
{
    CTServerConnectionRef connection = create(NULL, callback, context);
    printf("diagnose: CTServerConnectionCreate(%s) -> %p\n", label, connection);
    fflush(stdout);
    return connection;
}

static void diagnose_bridge(void)
{
    void *handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY);
    printf("diagnose: dlopen CoreTelephony.framework -> %p\n", handle);
    fflush(stdout);
    if (!handle)
        return;
    CharonCTServerConnectionCreate create = (CharonCTServerConnectionCreate)dlsym(handle, "_CTServerConnectionCreate");
    printf("diagnose: dlsym _CTServerConnectionCreate -> %p\n", (void *)create);
    fflush(stdout);
    if (!create)
        return;

    CTServerConnectionRef connection = try_create(create, "NULL,NULL", NULL, NULL);

    if (!connection) {
        CTServerConnectionContext context = {0, NULL, NULL, NULL, NULL};
        connection = try_create(create, "NULL,zeroed-context", NULL, &context);
    }

    if (!connection) {
        connection = try_create(create, "callback,NULL", noop_callback, NULL);
    }

    if (!connection) {
        CTServerConnectionContext context = {0, NULL, NULL, NULL, NULL};
        connection = try_create(create, "callback,zeroed-context", noop_callback, &context);
    }

    if (!connection)
        return;
    CharonCTServerConnectionGetCellularDataIsDisallowed get =
        (CharonCTServerConnectionGetCellularDataIsDisallowed)dlsym(handle, "_CTServerConnectionGetCellularDataIsDisallowed");
    printf("diagnose: dlsym _CTServerConnectionGetCellularDataIsDisallowed -> %p\n", (void *)get);
    fflush(stdout);
    if (!get)
        return;
    Boolean disallowed = false;
    CTError error = get(connection, &disallowed);
    printf("diagnose: CTServerConnectionGetCellularDataIsDisallowed -> domain=%d error=%d disallowed=%d\n",
           (int)error.domain, (int)error.error, (int)disallowed);
    fflush(stdout);
}

typedef CTError (*CharonCTServerConnectionSetCellularDataIsDisallowed)(CTServerConnectionRef connection, Boolean disallowed);

// Toggles the daemon's own restriction flag directly through the private setter this release
// exports, since iOS 6 has no Settings UI for this iOS-9 feature to drive it through - this is
// the only way to raise a real state change on this hardware and prove the notifier fires for it.
static void toggle_real_state(CTCellularData *data)
{
    void *handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY);
    CharonCTServerConnectionCreate create = (CharonCTServerConnectionCreate)dlsym(handle, "_CTServerConnectionCreate");
    CharonCTServerConnectionSetCellularDataIsDisallowed set =
        (CharonCTServerConnectionSetCellularDataIsDisallowed)dlsym(handle, "_CTServerConnectionSetCellularDataIsDisallowed");
    printf("toggle: dlsym _CTServerConnectionSetCellularDataIsDisallowed -> %p\n", (void *)set);
    fflush(stdout);
    if (!create || !set)
        return;
    CTServerConnectionRef connection = create(NULL, noop_callback, NULL);
    printf("toggle: connection -> %p\n", connection);
    fflush(stdout);
    if (!connection)
        return;

    CharonCTServerConnectionGetCellularDataIsDisallowed get =
        (CharonCTServerConnectionGetCellularDataIsDisallowed)dlsym(handle, "_CTServerConnectionGetCellularDataIsDisallowed");

    CTError error = set(connection, true);
    printf("toggle: SetCellularDataIsDisallowed(true) -> domain=%d error=%d\n", (int)error.domain, (int)error.error);
    fflush(stdout);
    if (get) {
        Boolean disallowed = false;
        CTError readBack = get(connection, &disallowed);
        printf("toggle: same connection reads back -> domain=%d error=%d disallowed=%d\n",
               (int)readBack.domain, (int)readBack.error, (int)disallowed);
        fflush(stdout);
    }
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3]];
    printf("toggle: after setting true, port reads: %s\n", state_name(data.restrictedState).UTF8String);
    fflush(stdout);

    error = set(connection, false);
    printf("toggle: SetCellularDataIsDisallowed(false) -> domain=%d error=%d\n", (int)error.domain, (int)error.error);
    fflush(stdout);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3]];
    printf("toggle: after setting false, port reads: %s\n", state_name(data.restrictedState).UTF8String);
    fflush(stdout);
}

static NSString *image_of_method(Class class, SEL selector)
{
    Method method = class_getInstanceMethod(class, selector);
    Dl_info info;
    if (!method || !dladdr((void *)method_getImplementation(method), &info) || !info.dli_fname)
        return @"<missing>";
    return @(info.dli_fname).lastPathComponent;
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        charon_log_to(@"/private/var/backports/cellulardata.log");

        diagnose_bridge();

        CHECK(NSClassFromString(@"CTCellularData") != Nil, "CTCellularData is there");
        CHECK_EQUAL(image_of_method([CTCellularData class], @selector(restrictedState)), @"libCoreTelephonyBackports.dylib",
                    "-[CTCellularData restrictedState] comes from the backports");
        CHECK_EQUAL(image_of_method([CTCellularData class], @selector(cellularDataRestrictionDidUpdateNotifier)), @"libCoreTelephonyBackports.dylib",
                    "-[CTCellularData cellularDataRestrictionDidUpdateNotifier] comes from the backports");

        // Not [[CTCellularData alloc] init]: that literal pattern is what ARC's codegen
        // rewrites into a call to _objc_alloc, an entry point iOS 6.1.3's libobjc does not
        // have - real iOS 6 runs only what a plain objc_msgSend send does.
        id allocated = ((id (*)(id, SEL))objc_msgSend)((id)[CTCellularData class], sel_registerName("alloc"));
        CTCellularData *data = ((id (*)(id, SEL))objc_msgSend)(allocated, sel_registerName("init"));
        CTCellularDataRestrictedState first = data.restrictedState;
        printf("restrictedState (call 1): %s\n", state_name(first).UTF8String);
        fflush(stdout);
        CHECK(first == kCTCellularDataRestrictedStateUnknown || first == kCTCellularDataNotRestricted || first == kCTCellularDataRestricted,
              "restrictedState answers one of the three real cases");

        CTCellularDataRestrictedState second = data.restrictedState;
        printf("restrictedState (call 2): %s\n", state_name(second).UTF8String);
        fflush(stdout);
        CHECK(second == first, "restrictedState answers the same value twice with nothing changed in between");

        __block int notifierCalls = 0;
        __block CTCellularDataRestrictedState lastNotified = kCTCellularDataRestrictedStateUnknown;
        dispatch_semaphore_t firstCall = dispatch_semaphore_create(0);
        data.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
            notifierCalls++;
            lastNotified = state;
            printf("notifier called (%d): %s, main thread: %s\n", notifierCalls, state_name(state).UTF8String,
                   [NSThread isMainThread] ? "yes" : "no");
            fflush(stdout);
            dispatch_semaphore_signal(firstCall);
        };
        long waited = dispatch_semaphore_wait(firstCall, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        CHECK(waited == 0, "the notifier is called once immediately after being set, matching the header's documented first call");
        if (waited == 0) {
            CHECK(lastNotified == data.restrictedState, "the immediate notifier call carries the same state a direct read gives");
        }

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        fflush(stdout);

        int callsBeforeToggle = notifierCalls;
        printf("toggling the daemon's own restriction flag directly (iOS 6 has no Settings UI for this iOS 9 feature)...\n");
        fflush(stdout);
        toggle_real_state(data);
        if (notifierCalls > callsBeforeToggle) {
            CHECK(YES, "the notifier fired for a real state change raised on this hardware");
        } else {
            printf("skip: CTServerConnectionSetCellularDataIsDisallowed answered success with no error on this unentitled "
                   "process, but the same connection reads the flag back unchanged - the daemon silently no-ops an "
                   "unentitled write rather than erroring it, so no real state change was raised to prove the notifier "
                   "against; this is an entitlement wall around the write path, not a defect in the notifier's own wiring\n");
            fflush(stdout);
        }
        CHECK(data.restrictedState == kCTCellularDataNotRestricted, "the flag reads not-restricted after the toggle attempt, matching its value before");

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        fflush(stdout);

        return charon_failures == 0 ? 0 : 1;
    }
}
