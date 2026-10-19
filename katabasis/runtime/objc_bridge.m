#include "objc_abi.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <Block.h>

#include "xl_bridge.h"
#include "xl_host.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>

extern const struct xl_selector_shim xl_selector_shims[];
extern const struct xl_selector_variant xl_selector_variants[];
extern const struct xl_imp_entry xl_imp_map[];
extern const struct xl_variadic_shim xl_variadic_shims[];
extern void xl_bridge_init_generated(void);
extern const uint32_t xl_initializers[];
extern const uint32_t xl_initializer_count;
extern void xl_tail(State *state);
extern void xl_fault(State *state, const char *reason);

static CFMutableDictionaryRef xl_selector_table;
static CFMutableDictionaryRef xl_selector_variant_table;  // SEL -> (encoding CFString -> guest addr)
static CFMutableDictionaryRef xl_variant_cache;           // host IMP -> guest addr (resolved variant)
static CFMutableDictionaryRef xl_guest_imps;
static CFMutableDictionaryRef xl_variadic_table;
static pthread_once_t xl_setup_once = PTHREAD_ONCE_INIT;
static pthread_key_t xl_super_key;
static void xl_load_rules(void);

static void xl_uncaught(NSException *exception)
{
    FILE *log = fopen("/private/var/charon/xlate-exception.log", "a");
    if (log) {
        fprintf(log, "uncaught %s: %s\n", [[exception name] UTF8String] ?: "?", [[exception reason] UTF8String] ?: "?");
        for (NSString *frame in [exception callStackSymbols]) {
            fprintf(log, "  %s\n", [frame UTF8String] ?: "?");
        }
        fclose(log);
    }
    fprintf(stderr, "xlate: uncaught %s: %s\n", [[exception name] UTF8String] ?: "?", [[exception reason] UTF8String] ?: "?");
}

static void xl_fix_layouts(void);

// EXPERIMENT (flag-file gated, diagnostics only): API-gap survey. With /private/var/charon/xl-exp-null-missing present,
// a message NO class implements is logged (class + selector, one line per distinct pair) to xl-missing.log and answered
// by this null object -- every unknown message returns nil/0 -- instead of raising "unrecognized selector". The app
// then keeps running and a single launch yields the full list of missing (backport-needed) methods.
@interface XLNullObject : NSObject
@end
@implementation XLNullObject
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    const char *n = sel_getName(sel);
    char enc[80] = "@@:";
    for (; *n && strlen(enc) < 70; n++)
        if (*n == ':')
            strcat(enc, "@");
    return [NSMethodSignature signatureWithObjCTypes:enc];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
    id nothing = nil;
    if ([[invocation methodSignature] methodReturnLength] == sizeof(id))
        [invocation setReturnValue:&nothing];
}
@end

static id xl_null_missing(id self_, SEL forwarding_sel, SEL missing)
{
    static NSMutableSet *seen;
    static XLNullObject *null_object;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seen = [[NSMutableSet alloc] init]; null_object = [[XLNullObject alloc] init]; });
    if (missing == @selector(forwardInvocation:) || missing == @selector(methodSignatureForSelector:) ||
        missing == @selector(_isDeallocating) || missing == @selector(_tryRetain))
        return nil;
    NSString *key = [NSString stringWithFormat:@"%s%s %s", class_isMetaClass(object_getClass(self_)) ? "+" : "-",
                     object_getClassName(self_), sel_getName(missing)];
    @synchronized (seen) {
        if (![seen containsObject:key]) {
            [seen addObject:key];
            int fd = open("/private/var/charon/xl-missing.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
            if (fd >= 0) { dprintf(fd, "%s\n", [key UTF8String]); close(fd); }
        }
    }
    return null_object;
}

// iOS 6 (and 7/8) run the Auto Layout pass INSIDE UIView's -layoutSubviews, and raise "Auto Layout still required after
// executing -layoutSubviews. X's implementation of -layoutSubviews needs to call super" if an override never reached it.
// Modern iOS (10+) runs the engine BEFORE calling the override, so apps written for it legitimately omit [super
// layoutSubviews] -- and would raise here. Emulate the modern order for the translated app's own UIView subclasses: wrap
// each override so UIView's implementation runs first, then the guest's (a guest that also calls super merely repeats an
// idempotent pass). Disabled by the flag file /private/var/charon/xl-no-layout-super.
// Memory profile (flag file /private/var/charon/xl-memlog): a run that vanishes with no crash and no exit() is usually
// the low-memory killer; sampling resident/virtual size every 100 ms into xl-mem.log leaves the profile up to the kill.
static void *xl_memlog_thread(void *arg)
{
    (void)arg;
    int fd = open("/private/var/charon/xl-mem.log", O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd < 0)
        return NULL;
    for (unsigned tick = 0;; tick++) {
        struct task_basic_info info;
        mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
        if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS)
            dprintf(fd, "t=%u.%u resident=%lu KB virtual=%lu MB\n", tick / 10, tick % 10, (unsigned long)(info.resident_size / 1024),
                    (unsigned long)(info.virtual_size / (1024 * 1024)));
        usleep(100000);
    }
    return NULL;
}

static void xl_wrap_layout_subviews(void)
{
    if (access("/private/var/charon/xl-no-layout-super", F_OK) == 0)
        return;
    const char *main_image = _dyld_get_image_name(0);
    Class view_class = [UIView class];
    unsigned count = 0;
    Class *classes = objc_copyClassList(&count);
    for (unsigned i = 0; i < count; i++) {
        Class cls = classes[i];
        const char *image = class_getImageName(cls);
        if (!image || !main_image || strcmp(image, main_image) != 0 || cls == view_class)
            continue;
        BOOL is_view = NO;
        for (Class c = class_getSuperclass(cls); c; c = class_getSuperclass(c))
            if (c == view_class) { is_view = YES; break; }
        if (!is_view)
            continue;
        unsigned methods = 0;
        Method *list = class_copyMethodList(cls, &methods);
        for (unsigned m = 0; m < methods; m++) {
            if (method_getName(list[m]) != @selector(layoutSubviews))
                continue;
            IMP original = method_getImplementation(list[m]);
            Class defining = cls;
            IMP wrapped = imp_implementationWithBlock(^(id self_) {
                struct objc_super sup = {self_, class_getSuperclass(defining)};
                ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&sup, @selector(layoutSubviews));
                ((void (*)(id, SEL))original)(self_, @selector(layoutSubviews));
            });
            method_setImplementation(list[m], wrapped);
        }
        free(list);
    }
    free(classes);
}

static void xl_setup(void)
{
    NSSetUncaughtExceptionHandler(xl_uncaught);
    { FILE *f = fopen("/private/var/charon/xlate-trace.log", "a"); if (f) { fprintf(f, "fix start\n"); fclose(f); } }
    xl_fix_layouts();
    { FILE *f = fopen("/private/var/charon/xlate-trace.log", "a"); if (f) { fprintf(f, "fix done\n"); fclose(f); } }
    xl_shadow_init();
    xl_load_rules();
    pthread_key_create(&xl_super_key, NULL);
    xl_selector_table = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_guest_imps = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    for (const struct xl_selector_shim *shim = xl_selector_shims; shim->selector; shim++)
        CFDictionarySetValue(xl_selector_table, sel_registerName(shim->selector), (void *)(uintptr_t)shim->guest);
    for (const struct xl_imp_entry *entry = xl_imp_map; entry->imp; entry++)
        CFDictionarySetValue(xl_guest_imps, entry->imp, (void *)(uintptr_t)entry->guest);
    // Ambiguous-selector variants: SEL -> (type-encoding -> guest bridge). Built once; xl_route
    // then dispatches a polymorphic selector to the bridge matching the receiver's real method.
    xl_selector_variant_table = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_variant_cache = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    // EXPERIMENT (flag-file gated, NOT part of the translator): find the layers behind a backports gap
    // without a round trip. Real UIKit's constraint validation (_UIViewConstraintWithItemsIsPotentially-
    // Dangly) sends -superview to a UILayoutGuide constraint item; give the guide that method here.
    xl_wrap_layout_subviews();
    if (access("/private/var/charon/xl-memlog", F_OK) == 0) {
        pthread_t thread;
        pthread_create(&thread, NULL, xl_memlog_thread, NULL);
    }
    if (access("/private/var/charon/xl-exp-null-missing", F_OK) == 0) {
        IMP imp = imp_implementationWithBlock(^id(id self_, SEL missing) { return xl_null_missing(self_, 0, missing); });
        class_replaceMethod([NSObject class], @selector(forwardingTargetForSelector:), imp, "@@::");
        class_replaceMethod(object_getClass([NSObject class]), @selector(forwardingTargetForSelector:), imp, "@@::");
    }
    // EXPERIMENT (flag-file gated, diagnostics only): /private/var/charon/xl-stubs.txt lists "+Class selector" or
    // "-Class selector" lines; each named method that the class does not implement is added, answering nil/0. Where
    // xl-exp-null-missing cannot reach (CoreFoundation does not always consult the NSObject forwarding hook), this
    // steps a translated app past one API gap at a time to find the next -- without a rebuild. The list of stubbed
    // names is the hand-off to whoever owns the backport.
    FILE *stubs = fopen("/private/var/charon/xl-stubs.txt", "r");
    if (stubs) {
        char line[256];
        while (fgets(line, sizeof line, stubs)) {
            char cls[128], sel[128];
            // "+"/"-" add the method where the class lacks it; "=" (instance) / "#" (class) REPLACE an existing one --
            // iOS 6 Foundation ships some later-OS selectors as stubs that raise doesNotRecognizeSelector (for example
            // -[NSBundle appStoreReceiptURL]), so respondsToSelector: says yes and the call still throws.
            char kind = line[0];
            if ((kind != '+' && kind != '-' && kind != '=' && kind != '#') || sscanf(line + 1, "%127s %127s", cls, sel) != 2)
                continue;
            Class target = objc_getClass(cls);
            if ((kind == '+' || kind == '#') && target)
                target = object_getClass(target);
            SEL selector = sel_registerName(sel);
            if (!target || ((kind == '+' || kind == '-') && class_getInstanceMethod(target, selector)))
                continue;
            IMP nothing = imp_implementationWithBlock(^id(id self_) { return nil; });
            class_replaceMethod(target, selector, nothing, "@@:");
            int fd = open("/private/var/charon/xl-hooks.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
            if (fd >= 0) { dprintf(fd, "stub %c%s %s\n", kind, cls, sel); close(fd); }
        }
        fclose(stubs);
    }
    if (access("/private/var/charon/xl-exp-guide-superview", F_OK) == 0) {
        Class guide = NSClassFromString(@"UILayoutGuide");
        if (guide && !class_getInstanceMethod(guide, @selector(superview))) {
            IMP imp = imp_implementationWithBlock(^id(id self_) { return [self_ performSelector:@selector(owningView)]; });
            class_addMethod(guide, @selector(superview), imp, "@@:");
        }
        // Real UIKit's Auto Layout engine also probes private item methods on every constraint item
        // (_supportsContentDimensionVariables, ...). Forward whatever a guide does not implement to its
        // owning view, and LOG each selector so the complete list can be handed to the backports owner.
        if (guide) {
            // A guide has no content-size variables of its own.
            IMP no = imp_implementationWithBlock(^BOOL(id self_) { return NO; });
            class_addMethod(guide, NSSelectorFromString(@"_supportsContentDimensionVariables"), no, "c@:");
        }
        if (guide) {
            IMP fwd = imp_implementationWithBlock(^id(id self_, SEL sel) {
                id owner = [self_ performSelector:@selector(owningView)];
                if (owner && [owner respondsToSelector:sel]) {
                    int fd = open("/private/var/charon/xl-exp.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
                    if (fd >= 0) { dprintf(fd, "UILayoutGuide forwarded -%s to owningView\n", sel_getName(sel)); close(fd); }
                    return owner;
                }
                return nil;
            });
            class_replaceMethod(guide, @selector(forwardingTargetForSelector:), fwd, "@@::");
        }
    }
    for (const struct xl_selector_variant *v = xl_selector_variants; v->selector; v++) {
        SEL sel = sel_registerName(v->selector);
        CFMutableDictionaryRef by_enc = (CFMutableDictionaryRef)CFDictionaryGetValue(xl_selector_variant_table, sel);
        if (!by_enc) {
            by_enc = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
            CFDictionarySetValue(xl_selector_variant_table, sel, by_enc);
        }
        CFStringRef enc = CFStringCreateWithCString(NULL, v->encoding, kCFStringEncodingUTF8);
        CFDictionarySetValue(by_enc, enc, (void *)(uintptr_t)v->guest);
        CFRelease(enc);
    }
    xl_variadic_table = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    for (const struct xl_variadic_shim *shim = xl_variadic_shims; shim->selector; shim++)
        CFDictionarySetValue(xl_variadic_table, sel_registerName(shim->selector), (void *)shim->handler);
    xl_bridge_init_generated();
}

// Storyboards compiled by a recent Xcode name segue-template classes that iOS 6 does not have
// (UIStoryboardShowSegueTemplate, ...): unarchiving the storyboard throws NSInvalidUnarchiveOperation
// "Could not instantiate class named ..." on the first scene. Register the missing names as subclasses of
// the closest iOS 6 template so the unarchive succeeds and the segue behaves as its iOS 6 counterpart
// (show -> push, presentation -> modal). A stand-in only when the class is absent.
static void xl_register_storyboard_segues(void)
{
    static const struct { const char *name, *base; } segues[] = {
        {"UIStoryboardShowSegueTemplate", "UIStoryboardPushSegueTemplate"},
        {"UIStoryboardShowDetailSegueTemplate", "UIStoryboardPushSegueTemplate"},
        {"UIStoryboardPresentationSegueTemplate", "UIStoryboardModalSegueTemplate"},
    };
    for (size_t i = 0; i < sizeof(segues) / sizeof(segues[0]); i++) {
        if (objc_getClass(segues[i].name))
            continue;
        Class base = objc_getClass(segues[i].base) ?: objc_getClass("UIStoryboardSegueTemplate");
        if (!base)
            continue;
        Class cls = objc_allocateClassPair(base, segues[i].name, 0);
        if (cls)
            objc_registerClassPair(cls);
    }
}

void xl_run_initializers(void)
{
    xl_bridge_init();
    xl_register_storyboard_segues();
    int trace = getenv("XL_INIT_TRACE") ? open("/private/var/charon/init-trace.log",
                                               O_WRONLY | O_CREAT | O_TRUNC, 0666) : -1;
    for (uint32_t i = 0; i < xl_initializer_count; i++) {
        if (trace >= 0)
            dprintf(trace, "init %u/%u guest=0x%x\n", i, xl_initializer_count, xl_initializers[i]);
        xl_invoke(xl_initializers[i], 0);
    }
    if (trace >= 0) { dprintf(trace, "all initializers done\n"); close(trace); }
}

void xl_bridge_init(void)
{
    pthread_once(&xl_setup_once, xl_setup);
    // After the setup, not inside it: registering a class can run a guest +initialize, which calls back in here.
    xl_shadow_register_listed();
}

void *xl_take_super_class(State *state)
{
    void *cls = pthread_getspecific(xl_super_key);
    if (cls)
        pthread_setspecific(xl_super_key, NULL);
    return cls;
}

static void xl_zero_result(State *state)
{
    XL_REG(state, X0) = 0;
    XL_REG(state, X1) = 0;
    for (unsigned i = 0; i < 4; i++) {
        *(uint64_t *)((char *)state + XL_OFFSET_V0 + 16 * i) = 0;
        *(uint64_t *)((char *)state + XL_OFFSET_V0 + 16 * i + 8) = 0;
    }
}

static NSMutableArray *xl_neutralized_prefixes;
static NSMutableSet *xl_neutralized_selectors;

extern CGImageRef UIGetScreenImage(void);
static double xl_shot_delay;
static NSString *xl_shot_path;

static void *xl_shot_thread(void *unused)
{
    struct timespec ts = {(time_t)xl_shot_delay, (long)((xl_shot_delay - (time_t)xl_shot_delay) * 1e9)};
    nanosleep(&ts, NULL);
    dispatch_async(dispatch_get_main_queue(), ^{
        CGImageRef image = UIGetScreenImage();
        if (image) {
            NSData *png = UIImagePNGRepresentation([UIImage imageWithCGImage:image]);
            CGImageRelease(image);
            [png writeToFile:xl_shot_path atomically:YES];
        }
    });
    return NULL;
}

static void xl_load_rules(void)
{
    xl_neutralized_prefixes = [[NSMutableArray alloc] init];
    xl_neutralized_selectors = [[NSMutableSet alloc] init];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"xlate" ofType:@"rules"];
    NSString *text = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] : nil;
    for (NSString *raw in [text componentsSeparatedByString:@"\n"]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
        if ([line hasPrefix:@"neutralize-class "])
            [xl_neutralized_prefixes addObject:[[line substringFromIndex:[@"neutralize-class " length]] stringByTrimmingCharactersInSet:ws]];
        else if ([line hasPrefix:@"neutralize-selector "])
            [xl_neutralized_selectors addObject:[[line substringFromIndex:[@"neutralize-selector " length]] stringByTrimmingCharactersInSet:ws]];
        else if ([line hasPrefix:@"screenshot "]) {
            NSArray *parts = [[line substringFromIndex:11] componentsSeparatedByString:@" "];
            if (parts.count >= 2) {
                xl_shot_delay = [parts[0] doubleValue];
                xl_shot_path = [parts[1] copy];
            }
        }
    }
    if (xl_shot_path) {
        pthread_t t;
        pthread_create(&t, NULL, xl_shot_thread, NULL);
        pthread_detach(t);
    }
}

static int xl_selector_neutralized(SEL selector)
{
    return xl_neutralized_selectors.count && [xl_neutralized_selectors containsObject:[NSString stringWithUTF8String:sel_getName(selector)]];
}

static int xl_class_neutralized(Class cls)
{
    if (!xl_neutralized_prefixes.count)
        return 0;
    // Match the class or any ancestor, so a neutralized service is absent as a whole:
    // this catches the KVO runtime subclass (NSKVONotifying_GAI, whose superclass is GAI)
    // and every subclass of a neutralized class, not just names carrying the prefix.
    for (Class c = cls; c; c = class_getSuperclass(c)) {
        const char *name = class_getName(c);
        if (!name)
            continue;
        NSString *n = [NSString stringWithUTF8String:name];
        for (NSString *prefix in xl_neutralized_prefixes)
            if ([n hasPrefix:prefix])
                return 1;
    }
    return 0;
}

void xl_report_guest_frame(void);

// xl_route's answer for a message whose selector has no guest bridge (xlgen only knows selectors that appear in the
// SDK headers and in the app): the caller then marshals the call from the runtime's own method type encoding.
#define XL_NO_BRIDGE ((uint64_t)-1)

static void xl_dynamic_send(State *state, id receiver, Class lookup, SEL selector);

static uint64_t xl_route(State *state, Class lookup, SEL selector, id receiver, Class super_class)
{
    if (xl_selector_neutralized(selector) || xl_class_neutralized(lookup))
        return 0;
    // class_getMethodImplementation runs the class's +initialize on first use, and a guest +initialize executes on
    // THIS thread's register state: it clobbers the argument registers of the message being routed (a message to
    // an uninitialized class arrived at its method with x2 = the +initialize IMP). Keep the state across the lookup.
    uint8_t saved[XL_STATE_SIZE] __attribute__((aligned(16)));
    memcpy(saved, state, XL_STATE_SIZE);
    IMP imp = class_getMethodImplementation(lookup, selector);
    memcpy(state, saved, XL_STATE_SIZE);
    uintptr_t guest = (uintptr_t)CFDictionaryGetValue(xl_guest_imps, imp);
    if (!guest)
        guest = xl_shadow_imp(imp);
    if (guest)
        return guest;
    // Polymorphic selector: pick the bridge whose signature matches the receiver's ACTUAL method,
    // not the majority-voted one. Cache by IMP (uniquely identifies method + signature); the
    // encoding lookup runs only on the first miss for a given IMP.
    if (imp) {
        uintptr_t cached = (uintptr_t)CFDictionaryGetValue(xl_variant_cache, imp);
        if (cached)
            return cached;
    }
    CFMutableDictionaryRef by_enc = (CFMutableDictionaryRef)CFDictionaryGetValue(xl_selector_variant_table, selector);
    if (by_enc) {
        Method method = class_getInstanceMethod(lookup, selector);
        const char *enc = method ? method_getTypeEncoding(method) : NULL;
        if (enc) {
            // Normalise to match xlgen's NormalizeEncoding: strip offset digits and replace
            // struct/union tag names with '?' (device runtime encodings are anonymous {?=...}).
            char stripped[256];
            int j = 0;
            for (const char *p = enc; *p && j < (int)sizeof stripped - 1;) {
                char c = *p;
                if (isdigit((unsigned char)c)) { p++; continue; }
                stripped[j++] = c;
                if ((c == '{' || c == '(') && j < (int)sizeof stripped - 1) {
                    stripped[j++] = '?';
                    p++;
                    while (*p && *p != '=' && *p != '}' && *p != ')') p++;
                    continue;
                }
                p++;
            }
            stripped[j] = 0;
            CFStringRef key = CFStringCreateWithCString(NULL, stripped, kCFStringEncodingUTF8);
            uintptr_t variant = (uintptr_t)CFDictionaryGetValue(by_enc, key);
            CFRelease(key);
            if (variant) {
                if (imp)
                    CFDictionarySetValue(xl_variant_cache, imp, (void *)variant);
                return variant;
            }
            // No variant matched the runtime encoding: fall back to the voted default below, but
            // log it — a miss on a class that really exists on this release means the SDK encoding
            // xlgen recorded drifted from the device libobjc's, which we'd want to reconcile.
            FILE *f = fopen("/private/var/charon/xlate-variant-miss.log", "a");
            if (f) {
                fprintf(f, "-[%s %s] enc=%s: no variant match, using default\n",
                        class_getName(lookup), sel_getName(selector), stripped);
                fclose(f);
            }
        }
    }
    guest = (uintptr_t)CFDictionaryGetValue(xl_selector_table, selector);
    if (!guest) {
        fprintf(stderr, "xlate: no bridge for -[%s %s]\n", class_getName(lookup), sel_getName(selector));
        // stderr is invisible for an app SpringBoard launched: keep the receiver class and selector in a file
        // (an abort otherwise says only "message without a bridge").
        FILE *nb = fopen("/private/var/charon/xlate-nobridge.log", "a");
        if (nb) {
            fprintf(nb, "%c[%s %s]\n", class_isMetaClass(lookup) ? '+' : '-', class_getName(lookup), sel_getName(selector));
            fclose(nb);
        }
        fprintf(stderr, "xlate:   receiver=%p isa=0x%x lookup=%p(%s) isMeta=%d imp=%p\n",
                (void *)receiver, receiver ? *(uint32_t *)receiver : 0, (void *)lookup, class_getName(lookup),
                class_isMetaClass(lookup), (void *)imp);
        xl_report_guest_frame();
        // Collect mode: env XL_COLLECT, or a flag file (env does not propagate to a
        // SpringBoard-launched app on iOS 6). Log the missing selector and neutralize it
        // (return 0) so the app runs on and surfaces every gap in one pass.
        if (getenv("XL_COLLECT") || access("/private/var/charon/xl-collect", F_OK) == 0) {
            FILE *log = fopen("/private/var/charon/xlate-missing.log", "a");
            if (log) { fprintf(log, "-[%s %s]\n", class_getName(lookup), sel_getName(selector)); fclose(log); }
            return 0;
        }
        return XL_NO_BRIDGE;
    }
    if (super_class)
        pthread_setspecific(xl_super_key, super_class);
    return guest;
}

static int xl_is_guest_block(uint64_t guest);
static struct xl_block_wrapper *xl_wrapper_for(uint64_t guest);
uint64_t xl_object_out(uintptr_t host);

// A message no generated bridge covers (typically a private or newer-SDK selector on a system class, e.g.
// +[AXSpringBoardServer server]). Marshal it from the receiver's real method type encoding instead of faulting:
// integer/pointer/object arguments come straight from the guest argument registers (x2...), and a scalar, object or
// pointer result goes back in x0. Floating-point, struct arguments/results and stack-passed arguments are not
// handled and still fault, naming the selector. A receiver that does not implement the selector is sent the plain
// message, so the host raises (or forwards) exactly as it would for a native caller.
static void xl_dynamic_send(State *state, id receiver, Class lookup, SEL selector)
{
    Method method = class_getInstanceMethod(lookup, selector);
    if (!method) {
        ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    unsigned argc = method_getNumberOfArguments(method);
    uint32_t words[16];
    unsigned used = 2;
    words[0] = (uint32_t)(uintptr_t)receiver;
    words[1] = (uint32_t)(uintptr_t)selector;
    if (argc > 8)
        xl_fault(state, "message without a bridge (stack-passed arguments)");
    for (unsigned i = 2; i < argc; i++) {
        char *type = method_copyArgumentType(method, i);
        uint64_t value = *(uint64_t *)((char *)state + XL_OFFSET_X0 + i * 8);
        const char *t = type;
        while (*t == 'r' || *t == 'n' || *t == 'N' || *t == 'o' || *t == 'O' || *t == 'R' || *t == 'V')
            t++;
        int wide = 0;
        uint32_t word = 0;
        switch (*t) {
        case '@': word = (uint32_t)xl_object_in(value, "dynamic message", i); break;
        case '#': word = (uint32_t)(uintptr_t)xl_class_in(xl_narrow_pointer(value, "dynamic message", i)); break;
        case ':': case '^': case '*':
            word = (uint32_t)xl_narrow_pointer(value, "dynamic message", i);
            break;
        case 'c': case 'C': case 's': case 'S': case 'i': case 'I': case 'l': case 'L': case 'B':
            word = (uint32_t)value;
            break;
        case 'q': case 'Q': wide = 1; break;
        default:
            free(type);
            xl_fault(state, "message without a bridge (argument type)");
        }
        if (wide) {
            if (used & 1)
                words[used++] = 0;
            words[used++] = (uint32_t)value;
            words[used++] = (uint32_t)(value >> 32);
        } else {
            words[used++] = word;
        }
        free(type);
    }
    char *ret = method_copyReturnType(method);
    const char *r = ret;
    while (*r == 'r' || *r == 'n' || *r == 'N' || *r == 'o' || *r == 'O' || *r == 'R' || *r == 'V')
        r++;
    IMP imp = method_getImplementation(method);
    typedef uintptr_t (*call32)(uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t,
                                uintptr_t, uintptr_t, uintptr_t, uintptr_t);
    typedef uint64_t (*call64)(uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t,
                               uintptr_t, uintptr_t, uintptr_t, uintptr_t);
    uint64_t result = 0;
    switch (*r) {
    case 'v': ((call32)imp)(words[0], words[1], words[2], words[3], words[4], words[5], words[6], words[7], words[8], words[9], words[10], words[11]); break;
    case 'q': case 'Q':
        result = ((call64)imp)(words[0], words[1], words[2], words[3], words[4], words[5], words[6], words[7], words[8], words[9], words[10], words[11]);
        break;
    case '@': case '#': case ':': case '^': case '*': case 'c': case 'C': case 's': case 'S': case 'i': case 'I': case 'l': case 'L': case 'B': {
        uintptr_t v = ((call32)imp)(words[0], words[1], words[2], words[3], words[4], words[5], words[6], words[7], words[8], words[9], words[10], words[11]);
        switch (*r) {
        case '@': case '#': result = xl_object_out(v); break;
        case ':': case '^': case '*': result = xl_widen_pointer(v); break;
        case 'c': result = (uint64_t)(int64_t)(int8_t)v; break;
        case 's': result = (uint64_t)(int64_t)(int16_t)v; break;
        case 'i': case 'l': result = (uint64_t)(int64_t)(int32_t)v; break;
        case 'B': case 'C': result = (uint8_t)v; break;
        case 'S': result = (uint16_t)v; break;
        default: result = (uint32_t)v; break;
        }
        break;
    }
    default:
        free(ret);
        xl_fault(state, "message without a bridge (return type)");
    }
    free(ret);
    XL_REG(state, X0) = result;
    xl_return(state);
}

void xl_h_objc_msgSend(State *state)
{
    uint64_t self = XL_REG(state, X0);
    if (!self) {
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    if (xl_is_guest_block(self)) {
        // Capture the selector and arguments before xl_wrapper_for: it re-enters the
        // guest (guest _Block_copy) and clobbers the caller-saved state registers.
        SEL bsel = (SEL)(uintptr_t)XL_REG(state, X1);
        uint64_t a2 = XL_REG(state, X2), a3 = XL_REG(state, X3), a4 = XL_REG(state, X4);
        struct xl_block_wrapper *w = xl_wrapper_for(self);
        id result = ((id (*)(id, SEL, uint64_t, uint64_t, uint64_t))objc_msgSend)((id)w, bsel, a2, a3, a4);
        objc_release((id)w);
        XL_REG(state, X0) = xl_object_out((uintptr_t)result);
        xl_return(state);
        return;
    }
    id receiver = (id)xl_narrow_pointer(self, "objc_msgSend", 0);
    SEL selector = (SEL)(uintptr_t)XL_REG(state, X1);
    // Flag-file-gated message trace: log every message's raw receiver pointer + selector with a
    // direct write() (no stdio buffering), so the LAST line written before a crash names the
    // faulting -[receiver selector]. Deliberately does NOT deref the receiver's isa here, so a
    // garbage/nil receiver is still recorded rather than crashing the trace itself.
    if (access("/private/var/charon/xl-trace", F_OK) == 0) {
        static int xl_tfd = -1;
        if (xl_tfd < 0)
            xl_tfd = open("/private/var/charon/xlate-msgtrace.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
        if (xl_tfd >= 0) {
            const char *sn = sel_getName(selector);
            // Probe the receiver without faulting: write() to /dev/null returns EFAULT for an
            // unmapped address, so this distinguishes a junk pointer (marshaling delivered garbage)
            // from a freed object that still has a plausible isa (a lifetime/over-release bug).
            static int xl_nf = -1;
            if (xl_nf < 0) xl_nf = open("/dev/null", O_WRONLY);
            const char *state_s = "UNMAPPED";
            char cls[128]; cls[0] = 0;
            if (receiver && xl_nf >= 0 && write(xl_nf, (void *)receiver, 4) == 4) {
                state_s = "mapped";
                uint32_t isa = *(uint32_t *)(uintptr_t)receiver;
                if (isa && write(xl_nf, (void *)(uintptr_t)isa, 4) == 4) {
                    const char *cn = class_getName((Class)(uintptr_t)isa);
                    // CFGetRetainCount sends -retainCount, which for a CLASS receiver initializes the class: the guest
                    // +initialize then runs on this state and clobbers the argument registers of the very message being
                    // traced (a Heisenbug: tracing alone made an FIRCoreDiagnosticsConnector message arrive with x2 = the
                    // +initialize IMP). Never send anything from the trace to a class object.
                    long rc = class_isMetaClass((Class)(uintptr_t)isa) ? -1 : CFGetRetainCount((CFTypeRef)receiver);
                    snprintf(cls, sizeof cls, " isa=0x%x class=%s rc=%ld", isa, cn ? cn : "?", rc);
                } else {
                    snprintf(cls, sizeof cls, " isa=0x%x(BADISA)", isa);
                }
            } else if (!receiver) {
                state_s = "nil";
            }
            char line[256];
            int n = snprintf(line, sizeof line, "%p %s [%s%s]", (void *)receiver, sn ? sn : "?", state_s, cls);
            if (sn && strchr(sn, ':'))
                n += snprintf(line + n, sizeof line - n, " x2=0x%llx", (unsigned long long)XL_REG(state, X2));
            if (n > (int)sizeof line - 2) n = (int)sizeof line - 2;
            line[n++] = '\n';
            write(xl_tfd, line, n);
            // Guest-built error messages are the fastest pointer to a failing lower layer (a C library
            // the app links reports through NSError): log the format string / error domain+code.
            if (sn && (!strcmp(sn, "stringWithFormat:") || !strcmp(sn, "errorWithDomain:code:userInfo:"))) {
                id arg = (id)xl_object_in(XL_REG(state, X2), "trace", 0);
                if (arg && [arg isKindOfClass:[NSString class]]) {
                    char tl[600];
                    int tn;
                    if (!strcmp(sn, "stringWithFormat:")) {
                        // Darwin arm64 passes variadic arguments on the guest STACK, in order from sp; show the
                        // first two as a string pointer and an integer (covers the common "%s, line %d").
                        uint64_t sp = XL_REG(state, SP);
                        uint64_t v0 = *(uint64_t *)(uintptr_t)sp, v1 = *(uint64_t *)(uintptr_t)(sp + 8);
                        const char *first = "";
                        if (v0 && v0 < 0x40000000u && write(xl_nf, (void *)(uintptr_t)v0, 1) == 1) first = (const char *)(uintptr_t)v0;
                        tn = snprintf(tl, sizeof tl, "    -> format = %s | arg0 = %.200s | int0 = %lld | int1 = %lld\n", [arg UTF8String], first, (long long)(int32_t)v0, (long long)(int32_t)v1);
                    }
                    else
                        tn = snprintf(tl, sizeof tl, "    -> error domain = %s code = %ld\n", [arg UTF8String], (long)(int64_t)XL_REG(state, X3));
                    if (tn > (int)sizeof tl) tn = (int)sizeof tl;
                    write(xl_tfd, tl, tn);
                }
            }
            // Paths handed to C code (mount points, fakefs roots) are a common source of "not normalized" style
            // failures: log what -fileSystemRepresentation / -path actually return.
            if (sn && state_s[0] == 'm' && (!strcmp(sn, "fileSystemRepresentation") || !strcmp(sn, "path")) &&
                strstr(cls, "NSURL")) {
                id v = ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
                const char *u = !strcmp(sn, "path") ? [(NSString *)v UTF8String] : (const char *)v;
                char tl[600];
                int tn = snprintf(tl, sizeof tl, "    -> %s = [%s]\n", sn, u ? u : "(nil)");
                if (tn > (int)sizeof tl) tn = (int)sizeof tl;
                write(xl_tfd, tl, tn);
            }
            // When the guest asks an NSException for its name/reason, log the text too: the guest's
            // own uncaught-exception handler is the only thing that ever reads them, and if its next
            // step crashes the process (it walks callStackReturnAddresses), the cause of the ORIGINAL
            // exception would otherwise be lost. Only for a mapped NSException receiver.
            if (sn && state_s[0] == 'm' && !strcmp(sn, "callStackReturnAddresses") && strstr(cls, "NSException")) {
                // Symbolicate the throw site with dladdr so the log names the image and function that
                // raised (real UIKit vs a backport vs app code) without a symbolicated crash report.
                NSArray *frames = ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
                for (NSUInteger i = 0; i < [frames count] && i < 24; i++) {
                    uintptr_t a = (uintptr_t)[[frames objectAtIndex:i] unsignedIntValue];
                    Dl_info info;
                    char fl[300];
                    if (dladdr((void *)a, &info) && info.dli_fname)
                        snprintf(fl, sizeof fl, "    frame %lu 0x%lx %s %s+0x%lx\n", (unsigned long)i, (unsigned long)a,
                                 strrchr(info.dli_fname, '/') ? strrchr(info.dli_fname, '/') + 1 : info.dli_fname,
                                 info.dli_sname ? info.dli_sname : "?", (unsigned long)(a - (uintptr_t)info.dli_saddr));
                    else
                        snprintf(fl, sizeof fl, "    frame %lu 0x%lx ?\n", (unsigned long)i, (unsigned long)a);
                    write(xl_tfd, fl, strlen(fl));
                }
            }
            if (sn && state_s[0] == 'm' && (!strcmp(sn, "reason") || !strcmp(sn, "name")) &&
                strstr(cls, "NSException")) {
                id text = ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
                const char *u = ([text isKindOfClass:[NSString class]]) ? [text UTF8String] : NULL;
                char tl[512];
                int tn = snprintf(tl, sizeof tl, "    -> %s = %s\n", sn, u ? u : "(nil)");
                if (tn > (int)sizeof tl) tn = (int)sizeof tl;
                write(xl_tfd, tl, tn);
            }
        }
    }
    if (getenv("XL_TRACK_DIAG")) {
        const char *sn = sel_getName(selector);
        if (sn && (!strcmp(sn, "trackAction:") || !strcmp(sn, "defaultTracker") || !strcmp(sn, "sharedInstance"))) {
            uint32_t classref = *(uint32_t *)(uintptr_t)0x1010ee60u;
            fprintf(stderr, "xlate: DIAG %s self=%p isa=0x%x class=%s classref[0x1010ee60]=0x%x\n",
                    sn, (void *)receiver, receiver ? *(uint32_t *)receiver : 0,
                    class_getName(object_getClass(receiver)), classref);
        }
    }
    // The class a message to this receiver looks its method up in: the shadow when the receiver is a guest class or an
    // instance of one, whose isa the host runtime cannot read.
    Class receiver_class = xl_class_of(receiver);
    if (xl_class_neutralized(receiver_class) || xl_selector_neutralized(selector)) {
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    void (*variadic)(State *) = (void (*)(State *))CFDictionaryGetValue(xl_variadic_table, selector);
    if (variadic) {
        variadic(state);
        return;
    }
    uint64_t target = xl_route(state, receiver_class, selector, receiver, Nil);
    if (xl_shadow_log_enabled())
        xl_shadow_note("msg %p %s: isa %x, class %p (%s), target %llx", (void *)receiver, sel_getName(selector),
                       receiver ? *(uint32_t *)receiver : 0, receiver_class, class_getName(receiver_class), (unsigned long long)target);
    if (target == XL_NO_BRIDGE) {
        xl_dynamic_send(state, (id)xl_class_in((uintptr_t)receiver), receiver_class, selector);
        return;
    }
    if (!target) {
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    XL_REG(state, PC) = target;
    [[clang::musttail]] return xl_tail(state);
}

void xl_h_objc_msgSendSuper2(State *state)
{
    uint64_t *guest_super = (uint64_t *)xl_narrow_pointer(XL_REG(state, X0), "objc_msgSendSuper2", 0);
    id receiver = (id)(uintptr_t)guest_super[0];
    Class current = xl_class_in(guest_super[1]);
    SEL selector = (SEL)(uintptr_t)XL_REG(state, X1);
    XL_REG(state, X0) = (uintptr_t)receiver;
    uint64_t target = xl_route(state, class_getSuperclass(current), selector, receiver, current);
    if (target == XL_NO_BRIDGE)
        xl_fault(state, "super message without a bridge");
    if (!target) {
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    XL_REG(state, PC) = target;
    [[clang::musttail]] return xl_tail(state);
}

void xl_h_xl_unsupported(State *state)
{
    const char *message = (const char *)xl_narrow_pointer(XL_REG(state, X0), "xl_unsupported", 0);
    // Collect mode (flag file): log the unbridged C import and return a zero result instead of
    // aborting, so one run surfaces every C-function gap on the way to a screen -- the sibling
    // of xl_route's objc collect mode. The zero return is a best-effort stub for the survey.
    if (access("/private/var/charon/xl-collect", F_OK) == 0) {
        FILE *log = fopen("/private/var/charon/xlate-missing.log", "a");
        if (log) { fprintf(log, "C %s\n", message); fclose(log); }
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    xl_unsupported(message);
}

void xl_unsupported_imp(id self, SEL selector)
{
    fprintf(stderr, "xlate: host called -[%s %s], whose bridge was not generated\n", object_getClassName(self), sel_getName(selector));
    abort();
}

@implementation XLGuestBlock {
    uint64_t _guestBlock;
}

+ (instancetype)holderWithGuestBlock:(uint64_t)guest
{
    XLGuestBlock *holder = [[self alloc] init];
    holder->_guestBlock = xl_invoke(XL_GUEST__Block_copy, guest);
    return [holder autorelease];
}

- (uint64_t)guestBlock
{
    return _guestBlock;
}

- (void)dealloc
{
    xl_invoke(XL_GUEST__Block_release, _guestBlock);
    [super dealloc];
}

@end

struct __attribute__((packed)) xl_fast_enumeration_pack {
    uint64_t self;
    uint64_t sel;
    uint64_t state;
    uint64_t buffer;
    uint64_t length;
    uint64_t r;
};

struct xl_guest_enumeration {
    uint64_t state;
    uint64_t items;
    uint64_t mutations;
    uint64_t extra[5];
};

void xl_manual_fast_enumeration(void *pack)
{
    struct xl_fast_enumeration_pack *p = pack;
    struct xl_guest_enumeration *guest = (struct xl_guest_enumeration *)xl_narrow_pointer(p->state, "countByEnumeratingWithState:objects:count:", 0);
    NSFastEnumerationState *host = (NSFastEnumerationState *)&guest->extra[0];
    id buffer[16];
    NSUInteger length = p->length < 16 ? (NSUInteger)p->length : 16;
    NSUInteger count = [(id)(uintptr_t)p->self countByEnumeratingWithState:host objects:buffer count:length];
    if (count) {
        uint64_t *items = [[NSMutableData dataWithLength:count * sizeof(uint64_t)] mutableBytes];
        for (NSUInteger i = 0; i < count; i++)
            items[i] = (uintptr_t)host->itemsPtr[i];
        guest->items = (uintptr_t)items;
        guest->extra[4] = host->mutationsPtr ? *host->mutationsPtr : 0;
        guest->mutations = (uintptr_t)&guest->extra[4];
        guest->state = 1;
    }
    p->r = count;
}

id xl_format_string_with_format(id self, SEL selector, id format, va_list arguments)
{
    return [[[(Class)self alloc] initWithFormat:format arguments:arguments] autorelease];
}

id xl_format_init_with_format(id self, SEL selector, id format, va_list arguments)
{
    return [self initWithFormat:format arguments:arguments];
}

void xl_format_append_format(id self, SEL selector, id format, va_list arguments)
{
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    [self appendString:text];
    [text release];
}

struct __attribute__((packed)) xl_init_format_pack {
    uint64_t self;
    uint64_t sel;
    uint64_t format;
    uint64_t arguments;
    uint64_t r;
};

// initWithFormat:arguments: receives an explicit va_list, so unlike the variadic format
// methods it cannot be reached through the inline-vararg path. The guest hands over a guest
// arm64 va_list, which the host method would misread as an armv7 one; rebuild the arguments
// from the guest va_list and format the string on the host side.
void xl_manual_init_with_format_arguments(void *pack)
{
    struct xl_init_format_pack *p = pack;
    struct xl_format format;
    xl_format_marshal_valist(&format, 0, (void *)xl_object_in(p->format, "initWithFormat:arguments:", 0), p->arguments,
                             "initWithFormat:arguments:");
    id result = [(id)(uintptr_t)p->self initWithFormat:(NSString *)format.object arguments:(va_list)format.arguments];
    xl_format_release(&format);
    p->r = xl_object_out((uintptr_t)result);
}

struct __attribute__((packed)) xl_weak_pack {
    uint64_t a0;
    uint64_t a1;
    uint64_t r;
};

struct __attribute__((packed)) xl_weak_pack1 {
    uint64_t a0;
    uint64_t r;
};

static id *xl_weak_slot(uint64_t address)
{
    return (id *)xl_narrow_pointer(address, "weak reference slot", 0);
}

// The objc runtime's "copy" calls return a malloc'd ARRAY of host pointers (32-bit slots). The guest reads 64-bit
// slots, so the array is rebuilt with widened entries; the guest releases it with free(), which the bridge
// forwards to the host allocator the new array came from. The generic bridge cannot marshal these ("pointer to
// const char *, whose layout differs"), which is what stopped Firebase's runtime scan in Zebra.
static uint64_t xl_widen_pointer_array(const void *const *host, unsigned count)
{
    uint64_t *guest = malloc(((size_t)count + 1) * sizeof *guest);
    if (!guest)
        return 0;
    for (unsigned i = 0; i < count; i++)
        guest[i] = xl_widen_pointer((uintptr_t)host[i]);
    guest[count] = 0;
    return (uint64_t)(uintptr_t)guest;
}

void xl_manual_objc_copyImageNames(void *pack)
{
    struct __attribute__((packed)) { uint64_t count, r; } *p = pack;
    unsigned count = 0;
    const char **names = objc_copyImageNames(&count);
    p->r = names ? xl_widen_pointer_array((const void *const *)names, count) : 0;
    free(names);
    if (p->count)
        *(unsigned *)xl_narrow_pointer(p->count, "objc_copyImageNames", 0) = names ? count : 0;
}

void xl_manual_objc_copyClassNamesForImage(void *pack)
{
    struct __attribute__((packed)) { uint64_t image, count, r; } *p = pack;
    unsigned count = 0;
    const char **names = objc_copyClassNamesForImage((const char *)xl_narrow_pointer(p->image, "objc_copyClassNamesForImage", 0), &count);
    p->r = names ? xl_widen_pointer_array((const void *const *)names, count) : 0;
    free(names);
    if (p->count)
        *(unsigned *)xl_narrow_pointer(p->count, "objc_copyClassNamesForImage", 1) = names ? count : 0;
}

void xl_manual_objc_copyClassList(void *pack)
{
    struct __attribute__((packed)) { uint64_t count, r; } *p = pack;
    unsigned count = 0;
    Class *classes = objc_copyClassList(&count);
    p->r = classes ? xl_widen_pointer_array((const void *const *)classes, count) : 0;
    // A shadow class is listed by the guest class it stands for.
    for (unsigned i = 0; p->r && i < count; i++)
        ((uint64_t *)(uintptr_t)p->r)[i] = xl_class_out((uintptr_t)classes[i]);
    free(classes);
    if (p->count)
        *(unsigned *)xl_narrow_pointer(p->count, "objc_copyClassList", 0) = classes ? count : 0;
}

void xl_manual_objc_initWeak(struct xl_weak_pack *p)
{
    id *slot = xl_weak_slot(p->a0);
    *(uint64_t *)slot = 0;
    p->r = (uintptr_t)objc_initWeak(slot, (id)xl_narrow_pointer(p->a1, "objc_initWeak", 1));
}

void xl_manual_objc_storeWeak(struct xl_weak_pack *p)
{
    p->r = (uintptr_t)objc_storeWeak(xl_weak_slot(p->a0), (id)xl_narrow_pointer(p->a1, "objc_storeWeak", 1));
}

void xl_manual_objc_destroyWeak(struct xl_weak_pack1 *p)
{
    objc_destroyWeak(xl_weak_slot(p->a0));
}

void xl_manual_objc_loadWeakRetained(struct xl_weak_pack1 *p)
{
    p->r = (uintptr_t)objc_loadWeakRetained(xl_weak_slot(p->a0));
}

void xl_manual_objc_loadWeak(struct xl_weak_pack1 *p)
{
    p->r = (uintptr_t)objc_loadWeak(xl_weak_slot(p->a0));
}

void xl_manual_objc_copyWeak(struct xl_weak_pack *p)
{
    id *to = xl_weak_slot(p->a0);
    *(uint64_t *)to = 0;
    objc_copyWeak(to, xl_weak_slot(p->a1));
}

void xl_manual_objc_moveWeak(struct xl_weak_pack *p)
{
    id *to = xl_weak_slot(p->a0);
    *(uint64_t *)to = 0;
    objc_moveWeak(to, xl_weak_slot(p->a1));
}

struct xl_guest_host_block {
    uint64_t isa;
    int32_t flags;
    int32_t reserved;
    uint64_t invoke;
    uint64_t descriptor;
    uint64_t host;
};

uint64_t xl_host_block_wrap(id block, uint32_t invoke, uint32_t descriptor)
{
    if (!block)
        return 0;
    struct xl_guest_host_block *guest = calloc(1, sizeof *guest);
    guest->isa = XL_GUEST__NSConcreteMallocBlock;
    guest->flags = (1 << 24) | (1 << 25) | 1;
    guest->invoke = invoke;
    guest->descriptor = descriptor;
    guest->host = (uintptr_t)_Block_copy(block);
    return (uintptr_t)guest;
}

void xl_h_xl_host_block_release(State *state)
{
    _Block_release((void *)xl_narrow_pointer(XL_REG(state, X0), "host block", 0));
    xl_return(state);
}

// A guest block and its host wrapper are one logical block with two ABI shapes: the
// invoke pointer sits at a different offset in each (armv7 12, arm64 16) so neither
// runtime can drive the other's representation. A+ keeps both, with a canonical
// mapping so the same guest block always yields the same wrapper (pointer identity,
// keys, comparison), one linked reference count (the wrapper holds one guest ref for
// its whole life), and per-side invocation.

extern void *_NSConcreteMallocBlock;

struct xl_block_desc {
    unsigned long reserved;
    unsigned long size;
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
    const char *signature;
};

struct xl_block_wrapper {
    void *isa;
    volatile int32_t flags;
    int32_t reserved;
    void *invoke;
    struct xl_block_desc *descriptor;
    uint64_t guest;
};

enum { XL_BLOCK_HAS_COPY_DISPOSE = 1 << 25, XL_BLOCK_HAS_SIGNATURE = 1 << 30, XL_BLOCK_NEEDS_FREE = 1 << 24 };

static pthread_mutex_t xl_block_lock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableDictionaryRef xl_block_forward;

static int xl_is_guest_block(uint64_t guest)
{
    if (!guest || guest >> 32)
        return 0;
    uint32_t isa = *(uint32_t *)(uintptr_t)guest;
    return isa == XL_GUEST__NSConcreteMallocBlock || isa == XL_GUEST__NSConcreteStackBlock ||
           isa == XL_GUEST__NSConcreteGlobalBlock || isa == XL_GUEST__NSConcreteAutoBlock;
}

// One ObjC type token: 'V' void, 'I' integer-like, 'P' pointer-like, 'X' unsupported.
static char xl_type_token(const char **p)
{
    while (**p == 'r' || **p == 'n' || **p == 'N' || **p == 'o' || **p == 'O' || **p == 'R' || **p == 'V')
        (*p)++;
    char c = **p;
    switch (c) {
    case 'v': (*p)++; return 'V';
    case 'c': case 'i': case 's': case 'l': case 'q':
    case 'C': case 'I': case 'S': case 'L': case 'Q': case 'B': (*p)++; return 'I';
    case '@':
        (*p)++;
        if (**p == '?') (*p)++;
        else if (**p == '"') { (*p)++; while (**p && **p != '"') (*p)++; if (**p == '"') (*p)++; }
        return 'P';
    case '#': case ':': case '*': (*p)++; return 'P';
    case '^': (*p)++; xl_type_token(p); return 'P';
    default: return 'X';
    }
}

// Count of real arguments (past the block parameter) when the signature is simple
// (void/integer/pointer return and args only); -1 if unsupported.
static int xl_block_simple_args(const char *sig)
{
    if (!sig)
        return -1;
    const char *p = sig;
    char ret = xl_type_token(&p);
    if (ret == 'X')
        return -1;
    while (*p >= '0' && *p <= '9') p++;
    if (xl_type_token(&p) != 'P')
        return -1;
    while (*p >= '0' && *p <= '9') p++;
    int count = 0;
    while (*p) {
        char t = xl_type_token(&p);
        if (t == 'X' || t == 'V')
            return -1;
        while (*p >= '0' && *p <= '9') p++;
        count++;
    }
    return count > 4 ? -1 : count;
}

static uintptr_t xl_block_call(struct xl_block_wrapper *w, const uint64_t *args, unsigned n)
{
    uint64_t invoke = *(uint64_t *)(uintptr_t)(w->guest + 16);
    uint64_t all[5];
    all[0] = w->guest;
    for (unsigned i = 0; i < n; i++)
        all[i + 1] = args[i];
    return (uintptr_t)xl_invoke_n(invoke, all, n + 1);
}

static uintptr_t xl_block_t0(void *b) { return xl_block_call(b, 0, 0); }
static uintptr_t xl_block_t1(void *b, uintptr_t a0) { uint64_t a[1] = {a0}; return xl_block_call(b, a, 1); }
static uintptr_t xl_block_t2(void *b, uintptr_t a0, uintptr_t a1) { uint64_t a[2] = {a0, a1}; return xl_block_call(b, a, 2); }
static uintptr_t xl_block_t3(void *b, uintptr_t a0, uintptr_t a1, uintptr_t a2) { uint64_t a[3] = {a0, a1, a2}; return xl_block_call(b, a, 3); }
static uintptr_t xl_block_t4(void *b, uintptr_t a0, uintptr_t a1, uintptr_t a2, uintptr_t a3) { uint64_t a[4] = {a0, a1, a2, a3}; return xl_block_call(b, a, 4); }
static void xl_block_unsupported_invoke(void *b) { (void)b; xl_unsupported("host-invoked guest block with a signature the bridge cannot marshal"); }

static const char *xl_guest_block_signature(uint64_t guest)
{
    int32_t flags = *(int32_t *)(uintptr_t)(guest + 8);
    if (!(flags & XL_BLOCK_HAS_SIGNATURE))
        return 0;
    uint64_t descriptor = *(uint64_t *)(uintptr_t)(guest + 24);
    if (!descriptor || descriptor >> 32)
        return 0;
    uint64_t at = descriptor + 16;
    if (flags & XL_BLOCK_HAS_COPY_DISPOSE)
        at += 16;
    uint64_t signature = *(uint64_t *)(uintptr_t)at;
    return (signature && signature >> 32 == 0) ? (const char *)(uintptr_t)signature : 0;
}

static void xl_block_copy_helper(void *dst, const void *src) { (void)dst; (void)src; }

static void xl_block_dispose_helper(const void *b)
{
    struct xl_block_wrapper *w = (struct xl_block_wrapper *)b;
    pthread_mutex_lock(&xl_block_lock);
    if (xl_block_forward)
        CFDictionaryRemoveValue(xl_block_forward, (const void *)(uintptr_t)(uint32_t)w->guest);
    pthread_mutex_unlock(&xl_block_lock);
    xl_invoke(XL_GUEST__Block_release, w->guest);
}

static struct xl_block_desc xl_block_descriptor = {
    0, sizeof(struct xl_block_wrapper), xl_block_copy_helper, xl_block_dispose_helper, 0
};

// Returns the canonical wrapper for a guest block with one extra reference for the
// caller: the same guest block always maps to the same wrapper, and every reference
// count (guest _Block_copy/_Block_release, host retain/release) funnels through the
// wrapper's single host count. The wrapper holds exactly one guest reference for its
// whole life; when the count reaches zero the dispose helper drops it.
static struct xl_block_wrapper *xl_wrapper_for(uint64_t guest)
{
    pthread_mutex_lock(&xl_block_lock);
    if (!xl_block_forward)
        xl_block_forward = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    struct xl_block_wrapper *w = (struct xl_block_wrapper *)CFDictionaryGetValue(xl_block_forward, (const void *)(uintptr_t)(uint32_t)guest);
    if (w) {
        _Block_copy(w);
        pthread_mutex_unlock(&xl_block_lock);
        return w;
    }
    w = calloc(1, sizeof *w);
    w->isa = &_NSConcreteMallocBlock;
    w->flags = XL_BLOCK_NEEDS_FREE | XL_BLOCK_HAS_COPY_DISPOSE | XL_BLOCK_HAS_SIGNATURE | 2;
    w->descriptor = &xl_block_descriptor;
    w->guest = xl_invoke(XL_GUEST__Block_copy, guest);
    int args = xl_block_simple_args(xl_guest_block_signature(guest));
    switch (args) {
    case 0: w->invoke = (void *)xl_block_t0; break;
    case 1: w->invoke = (void *)xl_block_t1; break;
    case 2: w->invoke = (void *)xl_block_t2; break;
    case 3: w->invoke = (void *)xl_block_t3; break;
    case 4: w->invoke = (void *)xl_block_t4; break;
    default: w->invoke = (void *)xl_block_unsupported_invoke; break;
    }
    CFDictionarySetValue(xl_block_forward, (const void *)(uintptr_t)(uint32_t)w->guest, w);
    pthread_mutex_unlock(&xl_block_lock);
    return w;
}

static struct xl_block_wrapper *xl_wrapper_of(uintptr_t host)
{
    if (host && *(void **)host == &_NSConcreteMallocBlock &&
        ((struct xl_block_wrapper *)host)->descriptor == &xl_block_descriptor)
        return (struct xl_block_wrapper *)host;
    return 0;
}

void xl_report_guest_frame(void);

uintptr_t xl_object_in(uint64_t guest, const char *symbol, unsigned index)
{
    if (guest && guest < 0x4000) {  // below __PAGEZERO: an integer reached an object slot
        fprintf(stderr, "xlate: %s argument %u is 0x%llx, not an object pointer\n", symbol, index, guest);
        xl_report_guest_frame();
        abort();
    }
    if (!xl_is_guest_block(guest))
        return (uintptr_t)xl_class_in(xl_narrow_pointer(guest, symbol, index));
    return (uintptr_t)objc_autorelease((id)xl_wrapper_for(guest));
}

uint64_t xl_object_out(uintptr_t host)
{
    struct xl_block_wrapper *w = xl_wrapper_of(host);
    return w ? w->guest : xl_class_out(host);
}

// Reference counting of a guest block routes to its wrapper so the two ABI shapes
// share one count.
uint64_t xl_block_retain(uint64_t guest)
{
    xl_wrapper_for(guest);
    return guest;
}

void xl_block_release(uint64_t guest)
{
    pthread_mutex_lock(&xl_block_lock);
    struct xl_block_wrapper *w = xl_block_forward ? (struct xl_block_wrapper *)CFDictionaryGetValue(xl_block_forward, (const void *)(uintptr_t)(uint32_t)guest) : 0;
    pthread_mutex_unlock(&xl_block_lock);
    if (w)
        _Block_release(w);
}

uint64_t xl_block_autorelease(uint64_t guest)
{
    objc_autorelease((id)xl_wrapper_for(guest));
    return guest;
}

uintptr_t xl_protocol(uint64_t guest)
{
    if (!guest)
        return 0;
    const char *name = (const char *)xl_narrow_pointer(*(uint32_t *)(uintptr_t)(guest + 4), "protocol name", 0);
    return name ? (uintptr_t)objc_getProtocol(name) : 0;
}

static uint64_t xl_variadic_arg(State *state, unsigned index)
{
    // Apple arm64: the named first object is in x2; the variadic rest are on the guest stack.
    if (index == 0)
        return XL_REG(state, X2);
    uint64_t sp = XL_REG(state, SP);
    return *(uint64_t *)(uintptr_t)xl_narrow_pointer(sp + 8 * (index - 1), "variadic argument", index);
}

void xl_h_dictionaryWithObjectsAndKeys(State *state)
{
    id self = (id)xl_narrow_pointer(XL_REG(state, X0), "dictionaryWithObjectsAndKeys:", 0);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (unsigned i = 0;; i += 2) {
        uint64_t value = xl_variadic_arg(state, i);
        if (!value)
            break;
        uint64_t key = xl_variadic_arg(state, i + 1);
        if (!key)
            break;
        [dict setObject:(id)(uintptr_t)value forKey:(id)(uintptr_t)key];
    }
    id result = [self isKindOfClass:object_getClass([NSMutableDictionary class])] ? dict : [[dict copy] autorelease];
    XL_REG(state, X0) = (uintptr_t)result;
    xl_return(state);
}

static void xl_collect_objects(State *state, NSMutableArray *array)
{
    for (unsigned i = 0;; i++) {
        uint64_t value = xl_variadic_arg(state, i);
        if (!value)
            break;
        [array addObject:(id)(uintptr_t)value];
    }
}

void xl_h_arrayWithObjects(State *state)
{
    NSMutableArray *array = [NSMutableArray array];
    xl_collect_objects(state, array);
    XL_REG(state, X0) = (uintptr_t)[[array copy] autorelease];
    xl_return(state);
}

void xl_h_initWithObjects(State *state)
{
    id self = (id)xl_narrow_pointer(XL_REG(state, X0), "initWithObjects:", 0);
    NSMutableArray *array = [NSMutableArray array];
    xl_collect_objects(state, array);
    id result = [self initWithArray:array];
    XL_REG(state, X0) = (uintptr_t)result;
    xl_return(state);
}

void xl_h_setWithObjects(State *state)
{
    NSMutableArray *array = [NSMutableArray array];
    xl_collect_objects(state, array);
    XL_REG(state, X0) = (uintptr_t)[NSSet setWithArray:array];
    xl_return(state);
}

// ARC return-value handling across the bridge must use the slow path: the fast
// path stores a token in thread-local storage expecting objc_retainAutoreleasedReturnValue
// to run as the very next call, but host ObjC inside the bridges runs in between and
// corrupts that token, which turned returned objects into nil downstream.
struct __attribute__((packed)) xl_arc_pack {
    uint64_t a0;
    uint64_t r;
};

// The reference counting calls of the host runtime dispatch on the object's class, which they cannot read when the object is
// an instance the guest allocated of a class that keeps the guest's layout (swift_classes.m): the guest's own -retain,
// -release and -autorelease answer for it.
static uintptr_t xl_host_retain(uint64_t guest, const char *symbol)
{
    id object = (id)xl_narrow_pointer(guest, symbol, 0);
    uint64_t result;
    return xl_guest_send(object, @selector(retain), &result) ? (uintptr_t)result : (uintptr_t)objc_retain(object);
}

static uintptr_t xl_host_autorelease(uint64_t guest, const char *symbol)
{
    id object = (id)xl_narrow_pointer(guest, symbol, 0);
    uint64_t result;
    return xl_guest_send(object, @selector(autorelease), &result) ? (uintptr_t)result : (uintptr_t)objc_autorelease(object);
}

static void xl_host_release(uint64_t guest, const char *symbol)
{
    id object = (id)xl_narrow_pointer(guest, symbol, 0);
    uint64_t ignored;
    if (!xl_guest_send(object, @selector(release), &ignored))
        objc_release(object);
}

void xl_manual_objc_autoreleaseReturnValue(struct xl_arc_pack *p)
{
    if (p->a0 && xl_is_guest_block(p->a0)) { p->r = xl_block_autorelease(p->a0); return; }
    p->r = xl_host_autorelease(p->a0, "objc_autoreleaseReturnValue");
}

void xl_manual_objc_retainAutoreleasedReturnValue(struct xl_arc_pack *p)
{
    if (p->a0 && xl_is_guest_block(p->a0)) { p->r = xl_block_retain(p->a0); return; }
    p->r = xl_host_retain(p->a0, "objc_retainAutoreleasedReturnValue");
}

void xl_manual_objc_claimAutoreleasedReturnValue(struct xl_arc_pack *p)
{
    if (p->a0 && xl_is_guest_block(p->a0)) { p->r = xl_block_retain(p->a0); return; }
    p->r = xl_host_retain(p->a0, "objc_claimAutoreleasedReturnValue");
}

void xl_manual_objc_retainAutoreleaseReturnValue(struct xl_arc_pack *p)
{
    if (p->a0 && xl_is_guest_block(p->a0)) { objc_autorelease((id)xl_wrapper_for(p->a0)); p->r = p->a0; return; }
    xl_host_retain(p->a0, "objc_retainAutoreleaseReturnValue");
    p->r = xl_host_autorelease(p->a0, "objc_retainAutoreleaseReturnValue");
}

void xl_manual_objc_unsafeClaimAutoreleasedReturnValue(struct xl_arc_pack *p)
{
    p->r = p->a0;
}

// A guest block carries the arm64 Block_layout (8-byte isa/invoke/descriptor, 8-byte
// descriptor size). Handing it to the host block runtime copies it by the armv7 layout,
// reading the size field at the wrong offset, so _Block_copy runs memmove over a garbage
// length. ARC block copies stay guest-side: copy through the guest's own Block runtime.
void xl_manual_objc_retainBlock(struct xl_arc_pack *p)
{
    p->r = (p->a0 && xl_is_guest_block(p->a0)) ? xl_block_retain(p->a0) : p->a0;
}

// Same flag-file-gated trace as the message path, for the ARC runtime ops (which do not go
// through objc_msgSend): the last op before a crash names the object being retained/released.
static void xl_arc_trace(uint64_t obj, const char *op)
{
    if (access("/private/var/charon/xl-trace", F_OK) != 0)
        return;
    static int fd = -1, nf = -1;
    if (fd < 0) fd = open("/private/var/charon/xlate-msgtrace.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (nf < 0) nf = open("/dev/null", O_WRONLY);
    if (fd < 0) return;
    const char *st = "UNMAPPED";
    char cls[128]; cls[0] = 0;
    if (obj && xl_is_guest_block(obj)) {
        // A guest block's isa is a block-class data symbol, not an ObjC class: class_getName /
        // CFGetRetainCount on it fault inside libobjc, so the trace helper itself crashed the app.
        st = "guest-block";
    } else if (obj && nf >= 0 && write(nf, (void *)(uintptr_t)obj, 4) == 4) {
        st = "mapped";
        uint32_t isa = *(uint32_t *)(uintptr_t)obj;
        if (isa && write(nf, (void *)(uintptr_t)isa, 4) == 4) {
            const char *cn = class_getName((Class)(uintptr_t)isa);
            snprintf(cls, sizeof cls, " isa=0x%x class=%s rc=%ld", isa, cn ? cn : "?", CFGetRetainCount((CFTypeRef)(uintptr_t)obj));
        } else {
            snprintf(cls, sizeof cls, " isa=0x%x(BADISA)", isa);
        }
    } else if (!obj) {
        st = "nil";
    }
    char line[256];
    int n = snprintf(line, sizeof line, "ARC %s %p [%s%s]\n", op, (void *)(uintptr_t)obj, st, cls);
    if (n > (int)sizeof line) n = (int)sizeof line;
    write(fd, line, n);
}

uint32_t xl_guest_imp_address(IMP imp)
{
    uintptr_t guest = imp ? (uintptr_t)CFDictionaryGetValue(xl_guest_imps, imp) : 0;
    return (uint32_t)(guest ? guest : xl_shadow_imp(imp));
}

void xl_manual_objc_retain(struct xl_arc_pack *p)
{
    xl_arc_trace(p->a0, "retain");
    if (p->a0 && xl_is_guest_block(p->a0))
        p->r = xl_block_retain(p->a0);
    else
        p->r = xl_host_retain(p->a0, "objc_retain");
}

void xl_manual_objc_release(struct xl_arc_pack *p)
{
    xl_arc_trace(p->a0, "release");
    if (p->a0 && xl_is_guest_block(p->a0))
        xl_block_release(p->a0);
    else
        xl_host_release(p->a0, "objc_release");
    p->r = 0;
}

void xl_manual_objc_autorelease(struct xl_arc_pack *p)
{
    if (p->a0 && xl_is_guest_block(p->a0))
        p->r = xl_block_autorelease(p->a0);
    else
        p->r = xl_host_autorelease(p->a0, "objc_autorelease");
}

extern const struct xl_class_layout xl_class_layouts[];

// Variant A: reconcile guest ObjC subclass ivar layout with the host superclass.
// The guest metadata carries arm64 offsets (8-byte slots, instanceStart sized for the
// arm64 superclass). On armv7 the host superclass has a different instanceSize, so the
// runtime's own ivar slide would use the wrong base and corrupt every offset. We do the
// slide ourselves with the real host superclass size, keeping the guest's 8-byte slots
// (no per-ivar repacking, so no NSInteger/int64 ambiguity), then set instanceStart to the
// host superclass size so the runtime leaves the class alone.
static const struct xl_class_layout *xl_find_layout(uint32_t address)
{
    for (const struct xl_class_layout *l = xl_class_layouts; l->ro; l++)
        if (l->address == address)
            return l;
    return NULL;
}

static CFMutableSetRef xl_fixed_layouts;

static int xl_is_writable(const void *address, kern_return_t *error)
{
    vm_address_t region = (vm_address_t)address;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object;
    *error = vm_region_64(mach_task_self(), &region, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &object);
    if (*error != KERN_SUCCESS)
        return 0;
    return region <= (vm_address_t)address && (info.protection & VM_PROT_WRITE);
}

static uint32_t xl_fix_layout(const struct xl_class_layout *l)
{
    if (!l)
        return 0;
    if (CFSetContainsValue(xl_fixed_layouts, l->ro))
        return l->ro->instance_size;
    CFSetAddValue(xl_fixed_layouts, l->ro);
    // Compute from the ORIGINAL guest values recorded at translation time, not from the
    // current class_ro: the ObjC runtime may have already realized (and mis-slid) this
    // class before this runs, so reading current fields would double-apply or read garbage.
    uint32_t super_size;
    if (l->super_guest) {
        super_size = xl_fix_layout(xl_find_layout(l->super_guest));
    } else if (l->super_host) {
        Class super = objc_getClass(l->super_host);
        super_size = super ? (uint32_t)class_getInstanceSize(super) : l->guest_instance_start;
    } else {
        super_size = l->guest_instance_start;
    }
    int32_t shift = (int32_t)super_size - (int32_t)l->guest_instance_start;
    // Only ever slide ivars UP. When the host superclass is SMALLER than the arm64
    // superclass (the common case, since 32-bit classes are smaller) the shift is
    // negative, but the lifted code still addresses ivars with the arm64 offsets --
    // baked as immediates (`str x0, [self, #40]`) where the compiler knew the layout,
    // or loaded from an offset variable it may have constant-folded. Packing the offsets
    // down would leave those accesses pointing at the old slots while the shrunk
    // instance size drops the last ivar's 8-byte slot past the end of the allocation,
    // so its high half is read/written out of bounds. Keeping the guest's arm64 slots
    // (a harmless gap after the smaller host isa) costs a few bytes and stays correct.
    if (shift < 0)
        shift = 0;
    // A Swift class keeps its field offsets in read-only memory: store only what changes. A guest chain
    // that ends at a guest root has no shift; one that ends at a host class can, and then a field offset
    // in read-only memory cannot follow the shift -- the class's code holds the arm64 layout as
    // constants -- so say which class it is instead of faulting on the store.
    for (uint32_t i = 0; i < l->ivar_count; i++) {
        int32_t offset = (int32_t)l->ivars[i].guest_offset + shift;
        if (*l->ivars[i].offset_var == offset)
            continue;
        kern_return_t error;
        if (!xl_is_writable(l->ivars[i].offset_var, &error)) {
            if (error != KERN_SUCCESS)
                fprintf(stderr, "xlate: class %s: the memory of a field offset that its host superclass moves by %d bytes cannot be queried (vm_region_64: %d)\n",
                        l->ro->name, (int)shift, (int)error);
            else
                fprintf(stderr, "xlate: class %s has a field offset in read-only memory that its host superclass moves by %d bytes\n",
                        l->ro->name, (int)shift);
            abort();
        }
        *l->ivars[i].offset_var = offset;
    }
    l->ro->instance_start = (uint32_t)((int32_t)l->guest_instance_start + shift);
    l->ro->instance_size = (uint32_t)((int32_t)l->guest_instance_size + shift);
    return l->ro->instance_size;
}

static void xl_fix_layouts(void)
{
    xl_fixed_layouts = CFSetCreateMutable(NULL, 0, NULL);
    for (const struct xl_class_layout *l = xl_class_layouts; l->ro; l++)
        xl_fix_layout(l);
}
