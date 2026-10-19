// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Exercise guest dynamic-store and reachability callbacks on the
// firmware run loop.

#include "system_configuration_probe.h"

typedef unsigned char Boolean;
typedef unsigned int uint32_t;
typedef signed long CFIndex;
typedef double CFTimeInterval;
typedef const void* CFTypeRef;
typedef const void* CFAllocatorRef;
typedef const void* CFStringRef;
typedef const void* CFArrayRef;
typedef const void* CFRunLoopRef;
typedef const void* CFRunLoopSourceRef;
typedef const void* SCDynamicStoreRef;
typedef const void* SCNetworkReachabilityRef;

typedef struct {
    CFIndex version;
    void* info;
    const void* (*retain)(const void* info);
    void (*release)(const void* info);
    CFStringRef (*copy_description)(const void* info);
} SCDynamicStoreContext;

typedef SCDynamicStoreContext SCNetworkReachabilityContext;
typedef void (*SCDynamicStoreCallback)(
    SCDynamicStoreRef store, CFArrayRef changed_keys, void* info);
typedef void (*SCNetworkReachabilityCallback)(
    SCNetworkReachabilityRef target, uint32_t flags, void* info);

extern int write(int descriptor, const void* bytes, unsigned long size);
extern CFStringRef CFStringCreateWithCString(
    CFAllocatorRef allocator, const char* text, uint32_t encoding);
extern CFArrayRef CFArrayCreate(CFAllocatorRef allocator, const void** values,
    CFIndex count, const void* callbacks);
extern CFIndex CFArrayGetCount(CFArrayRef array);
extern void CFRelease(CFTypeRef object);
extern CFRunLoopRef CFRunLoopGetCurrent(void);
extern void CFRunLoopAddSource(
    CFRunLoopRef run_loop, CFRunLoopSourceRef source, CFStringRef mode);
extern void CFRunLoopRemoveSource(
    CFRunLoopRef run_loop, CFRunLoopSourceRef source, CFStringRef mode);
extern int CFRunLoopRunInMode(CFStringRef mode, CFTimeInterval seconds,
    Boolean return_after_source_handled);
extern const CFStringRef kCFRunLoopDefaultMode;

extern SCDynamicStoreRef SCDynamicStoreCreate(CFAllocatorRef allocator,
    CFStringRef name, SCDynamicStoreCallback callback,
    SCDynamicStoreContext* context);
extern Boolean SCDynamicStoreSetNotificationKeys(
    SCDynamicStoreRef store, CFArrayRef keys, CFArrayRef patterns);
extern CFRunLoopSourceRef SCDynamicStoreCreateRunLoopSource(
    CFAllocatorRef allocator, SCDynamicStoreRef store, CFIndex order);
extern Boolean SCDynamicStoreSetValue(
    SCDynamicStoreRef store, CFStringRef key, CFTypeRef value);
extern CFTypeRef SCDynamicStoreCopyValue(
    SCDynamicStoreRef store, CFStringRef key);
extern Boolean SCDynamicStoreRemoveValue(
    SCDynamicStoreRef store, CFStringRef key);

extern SCNetworkReachabilityRef SCNetworkReachabilityCreateWithName(
    CFAllocatorRef allocator, const char* node_name);
extern Boolean SCNetworkReachabilityGetFlags(
    SCNetworkReachabilityRef target, uint32_t* flags);
extern Boolean SCNetworkReachabilitySetCallback(SCNetworkReachabilityRef target,
    SCNetworkReachabilityCallback callback,
    SCNetworkReachabilityContext* context);
extern Boolean SCNetworkReachabilityScheduleWithRunLoop(
    SCNetworkReachabilityRef target, CFRunLoopRef run_loop,
    CFStringRef run_loop_mode);
extern Boolean SCNetworkReachabilityUnscheduleFromRunLoop(
    SCNetworkReachabilityRef target, CFRunLoopRef run_loop,
    CFStringRef run_loop_mode);

enum {
    cf_string_encoding_utf8 = 0x08000100U,
};

static const char store_callback_marker[] = "PROBE sc store callback\n";
static const char store_failed_marker[] = "PROBE sc store failed\n";
static const char reachability_flags_marker[] = "PROBE sc reachability flags\n";
static const char reachability_callback_marker[] =
    "PROBE sc reachability callback\n";
static const char reachability_failed_marker[] =
    "PROBE sc reachability failed\n";

static volatile int store_callback_result;
static volatile int reachability_callback_result;

static void emit(const char* text, unsigned long size)
{
    (void)write(1, text, size);
}

static void store_callback(
    SCDynamicStoreRef store, CFArrayRef changed_keys, void* info)
{
    (void)store;
    (void)info;
    if (changed_keys != (CFArrayRef)0 && CFArrayGetCount(changed_keys) > 0) {
        store_callback_result = 1;
        emit(store_callback_marker, sizeof(store_callback_marker) - 1);
    } else {
        store_callback_result = -1;
    }
}

static void reachability_callback(
    SCNetworkReachabilityRef target, uint32_t flags, void* info)
{
    (void)target;
    (void)flags;
    (void)info;
    reachability_callback_result = 1;
    emit(
        reachability_callback_marker, sizeof(reachability_callback_marker) - 1);
}

static void run_loop_until_callback(volatile int* result)
{
    // SCDynamicStore first handles its CFMachPort source, which signals a
    // second user source. With returnAfterSourceHandled enabled those are
    // deliberately two run-loop turns. A few bounded turns also cover the
    // equivalent reachability source chain without making the probe hang on a
    // regression.
    const unsigned int maximum_turns = 16;
    for (unsigned int turn = 0; turn < maximum_turns && *result == 0; ++turn)
        (void)CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2.0, 1);
}

static int run_dynamic_store_probe(CFRunLoopRef run_loop)
{
    SCDynamicStoreContext context = { 0, (void*)0, (void*)0, (void*)0,
        (void*)0 };
    CFStringRef name = CFStringCreateWithCString((CFAllocatorRef)0,
        "Shade SystemConfiguration probe", cf_string_encoding_utf8);
    CFStringRef key = CFStringCreateWithCString(
        (CFAllocatorRef)0, "State:/Shade/Probe", cf_string_encoding_utf8);
    CFStringRef value = CFStringCreateWithCString(
        (CFAllocatorRef)0, "callback", cf_string_encoding_utf8);
    if (name == (CFStringRef)0 || key == (CFStringRef)0 ||
        value == (CFStringRef)0)
        return 0;

    SCDynamicStoreRef watcher =
        SCDynamicStoreCreate((CFAllocatorRef)0, name, store_callback, &context);
    SCDynamicStoreRef writer = SCDynamicStoreCreate((CFAllocatorRef)0, name,
        (SCDynamicStoreCallback)0, (SCDynamicStoreContext*)0);
    const void* key_values[1] = { key };
    CFArrayRef keys =
        CFArrayCreate((CFAllocatorRef)0, key_values, 1, (const void*)0);
    CFRunLoopSourceRef source = (CFRunLoopSourceRef)0;
    int success = watcher != (SCDynamicStoreRef)0 &&
                  writer != (SCDynamicStoreRef)0 && keys != (CFArrayRef)0;
    if (success) {
        success = SCDynamicStoreSetNotificationKeys(
                      watcher, keys, (CFArrayRef)0) != 0;
    }
    if (success) {
        source =
            SCDynamicStoreCreateRunLoopSource((CFAllocatorRef)0, watcher, 0);
        success = source != (CFRunLoopSourceRef)0;
    }
    if (success) {
        CFRunLoopAddSource(run_loop, source, kCFRunLoopDefaultMode);
        success = SCDynamicStoreSetValue(writer, key, value) != 0;
    }
    if (success) {
        run_loop_until_callback(&store_callback_result);
        CFTypeRef copied = SCDynamicStoreCopyValue(watcher, key);
        success = store_callback_result == 1 && copied != (CFTypeRef)0;
        if (copied != (CFTypeRef)0)
            CFRelease(copied);
        CFRunLoopRemoveSource(run_loop, source, kCFRunLoopDefaultMode);
        (void)SCDynamicStoreRemoveValue(writer, key);
    }

    if (source != (CFRunLoopSourceRef)0)
        CFRelease(source);
    if (keys != (CFArrayRef)0)
        CFRelease(keys);
    if (writer != (SCDynamicStoreRef)0)
        CFRelease(writer);
    if (watcher != (SCDynamicStoreRef)0)
        CFRelease(watcher);
    CFRelease(value);
    CFRelease(key);
    CFRelease(name);
    return success;
}

static int run_reachability_probe(CFRunLoopRef run_loop, const char* node_name)
{
    // Scheduling a name target starts the firmware's asynchronous resolver.
    // Its completion changes the target from first-resolution-pending and
    // therefore exercises the actual reachability callback contract.
    SCNetworkReachabilityContext context = { 0, (void*)0, (void*)0, (void*)0,
        (void*)0 };
    SCNetworkReachabilityRef target =
        SCNetworkReachabilityCreateWithName((CFAllocatorRef)0, node_name);
    uint32_t flags = 0;
    int success =
        target != (SCNetworkReachabilityRef)0 && node_name != (void*)0;
    if (success)
        success = SCNetworkReachabilitySetCallback(
                      target, reachability_callback, &context) != 0;
    if (success) {
        success = SCNetworkReachabilityScheduleWithRunLoop(
                      target, run_loop, kCFRunLoopDefaultMode) != 0;
    }
    if (success) {
        run_loop_until_callback(&reachability_callback_result);
        success = reachability_callback_result == 1;
        if (success)
            success = SCNetworkReachabilityGetFlags(target, &flags) != 0;
        if (success)
            emit(reachability_flags_marker,
                sizeof(reachability_flags_marker) - 1);
        (void)SCNetworkReachabilityUnscheduleFromRunLoop(
            target, run_loop, kCFRunLoopDefaultMode);
    }
    if (target != (SCNetworkReachabilityRef)0)
        CFRelease(target);
    return success;
}

int shade_run_system_configuration_probe(const char* reachability_name)
{
    CFRunLoopRef run_loop = CFRunLoopGetCurrent();
    if (run_loop == (CFRunLoopRef)0 || !run_dynamic_store_probe(run_loop)) {
        emit(store_failed_marker, sizeof(store_failed_marker) - 1);
        return 1;
    }
    if (!run_reachability_probe(run_loop, reachability_name)) {
        emit(
            reachability_failed_marker, sizeof(reachability_failed_marker) - 1);
        return 1;
    }
    return 0;
}
