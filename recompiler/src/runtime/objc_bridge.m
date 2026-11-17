#include "objc_abi.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <Block.h>

#include "xl_bridge.h"
#include "xl_diag.h"
#include "xl_host.h"
#include "xl_dlsym.h"

#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <mach-o/dyld.h>
#include <malloc/malloc.h>

extern const struct xl_selector_shim xl_selector_shims[];
extern const struct xl_selector_variant xl_selector_variants[];
extern const struct xl_imp_entry xl_imp_map[];
extern const struct xl_variadic_shim xl_variadic_shims[];
extern void xl_bridge_init_generated(void);
extern const uint32_t xl_initializers[];
extern const uint32_t xl_initializer_count;
extern void xl_tail(State *state);
extern void xl_call(State *state);
extern void xl_fault(State *state, const char *reason);

static CFMutableDictionaryRef xl_selector_table;
static CFMutableDictionaryRef xl_selector_variant_table;
static CFMutableDictionaryRef xl_variant_cache;
static pthread_mutex_t xl_variant_lock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableDictionaryRef xl_guest_imps;
static CFMutableDictionaryRef xl_variadic_table;
static pthread_once_t xl_setup_once = PTHREAD_ONCE_INIT;
static pthread_key_t xl_super_key;
static pthread_key_t xl_imp_key;
static void xl_load_rules(void);

static void xl_uncaught(NSException *exception)
{
    int log_fd = xl_log_open("xlate-exception.log");
    FILE *log = log_fd >= 0 ? fdopen(log_fd, "a") : NULL;
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

static void xl_wrap_layout_subviews(void)
{
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

static void xl_setup_application(void)
{
    NSSetUncaughtExceptionHandler(xl_uncaught);
    xl_load_rules();
    xl_wrap_layout_subviews();
}

static void xl_setup(void)
{
    xl_fix_layouts();
    xl_shadow_init();
    pthread_key_create(&xl_super_key, NULL);
    pthread_key_create(&xl_imp_key, NULL);
    xl_selector_table = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_guest_imps = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    for (const struct xl_selector_shim *shim = xl_selector_shims; shim->selector; shim++)
        CFDictionarySetValue(xl_selector_table, sel_registerName(shim->selector), (void *)(uintptr_t)shim->guest);
    for (const struct xl_imp_entry *entry = xl_imp_map; entry->imp; entry++)
        CFDictionarySetValue(xl_guest_imps, entry->imp, (void *)(uintptr_t)entry->guest);
    xl_selector_variant_table = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_variant_cache = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
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
#ifndef XL_LIBRARY
    xl_setup_application();
#endif
}

void xl_register_application_classes(void)
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
    static struct xl_diag_flag init_trace = {"xl-init-trace", 0};
    int trace = xl_diag_on(&init_trace) ? xl_diag_open("init-trace.log", O_TRUNC) : -1;
    for (uint32_t i = 0; i < xl_initializer_count; i++) {
        if (trace >= 0)
            dprintf(trace, "init %u/%u guest=0x%x\n", i, xl_initializer_count, xl_initializers[i]);
        xl_invoke(xl_initializers[i], 0);
    }
    if (trace >= 0) { dprintf(trace, "all initializers done\n"); close(trace); }
}

void xl_bridge_init(void)
{
    xl_word_init();
    pthread_once(&xl_setup_once, xl_setup);
    xl_shadow_register_listed();
}

void *xl_take_super_class(State *state)
{
    void *cls = pthread_getspecific(xl_super_key);
    if (cls)
        pthread_setspecific(xl_super_key, NULL);
    return cls;
}

void *xl_take_forced_imp(State *state)
{
    void *imp = pthread_getspecific(xl_imp_key);
    if (imp)
        pthread_setspecific(xl_imp_key, NULL);
    return imp;
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

#define XL_NO_BRIDGE ((uint64_t)-1)

#define XL_NOBRIDGE_SLOTS 4096
#define XL_NOBRIDGE_FULL 3
#define XL_NOBRIDGE_EVERY 10000

static uint32_t xl_nobridge_seen(Class lookup, SEL selector)
{
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    static struct { uintptr_t cls, sel; uint32_t count; } slots[XL_NOBRIDGE_SLOTS];
    uint32_t at = (uint32_t)(((uintptr_t)lookup * 31u + (uintptr_t)selector) % XL_NOBRIDGE_SLOTS);
    uint32_t seen = UINT32_MAX;
    pthread_mutex_lock(&lock);
    for (uint32_t probe = 0; probe < XL_NOBRIDGE_SLOTS; probe++) {
        uint32_t index = (at + probe) % XL_NOBRIDGE_SLOTS;
        if (!slots[index].count) {
            slots[index].cls = (uintptr_t)lookup;
            slots[index].sel = (uintptr_t)selector;
        }
        if (slots[index].cls == (uintptr_t)lookup && slots[index].sel == (uintptr_t)selector) {
            seen = ++slots[index].count;
            break;
        }
    }
    pthread_mutex_unlock(&lock);
    return seen;
}

static void xl_collect_note(const char *format, ...) __attribute__((format(printf, 1, 2)));

static void xl_collect_note(const char *format, ...)
{
    int descriptor = xl_diag_open("xlate-missing.log", O_APPEND);
    if (descriptor < 0)
        return;
    va_list arguments;
    va_start(arguments, format);
    vdprintf(descriptor, format, arguments);
    va_end(arguments);
    close(descriptor);
}

static int xl_collect_enabled(void)
{
    static struct xl_diag_flag collect = {"xl-collect", 0};
    return xl_diag_on(&collect);
}

#define XL_STATS_SLOTS 256
#define XL_STATS_EVERY 10000u
#define XL_STATS_FIRST 1000u
#define XL_STATS_SECOND 5000u
#define XL_STATS_TOP 4

struct xl_stats_slot {
    uintptr_t cls;
    uintptr_t sel;
    uint32_t count;
    uint64_t ticks;
};

static struct xl_stats_slot xl_stats_slots[XL_STATS_SLOTS];
static pthread_mutex_t xl_stats_lock = PTHREAD_MUTEX_INITIALIZER;
static uint32_t xl_stats_messages;
static uint32_t xl_stats_dynamic;
static uint64_t xl_stats_routing_ticks;
static uint64_t xl_stats_call_ticks;

uint64_t xl_stats_microseconds(uint64_t ticks)
{
    static mach_timebase_info_data_t base;
    if (!base.denom)
        mach_timebase_info(&base);
    return ticks * base.numer / base.denom / 1000u;
}

#define xl_stats_us xl_stats_microseconds

void xl_stats_snapshot(uint32_t *messages, uint32_t *dynamic, uint64_t *routing_ticks, uint64_t *call_ticks)
{
    pthread_mutex_lock(&xl_stats_lock);
    *messages = xl_stats_messages;
    *dynamic = xl_stats_dynamic;
    *routing_ticks = xl_stats_routing_ticks;
    *call_ticks = xl_stats_call_ticks;
    pthread_mutex_unlock(&xl_stats_lock);
}

#define XL_STATS_WINDOW_SLOTS 1024
#define XL_STATS_WINDOW_TOP 8

static struct xl_stats_slot xl_stats_window[XL_STATS_WINDOW_SLOTS];

static void xl_stats_window_note_locked(Class lookup, SEL selector, uint64_t ticks)
{
    unsigned start = (unsigned)((((uintptr_t)selector >> 2) ^ ((uintptr_t)lookup >> 4)) * 2654435761u) % XL_STATS_WINDOW_SLOTS;
    for (unsigned probe = 0; probe < XL_STATS_WINDOW_SLOTS; probe++) {
        struct xl_stats_slot *slot = &xl_stats_window[(start + probe) % XL_STATS_WINDOW_SLOTS];
        if (!slot->count) {
            slot->cls = (uintptr_t)lookup;
            slot->sel = (uintptr_t)selector;
        }
        if (slot->cls == (uintptr_t)lookup && slot->sel == (uintptr_t)selector) {
            slot->count++;
            slot->ticks += ticks;
            return;
        }
    }
}

void xl_stats_window_report(void)
{
    pthread_mutex_lock(&xl_stats_lock);
    const struct xl_stats_slot *top[XL_STATS_WINDOW_TOP] = {0};
    for (unsigned i = 0; i < XL_STATS_WINDOW_SLOTS; i++) {
        const struct xl_stats_slot *slot = &xl_stats_window[i];
        if (!slot->count)
            continue;
        for (unsigned t = 0; t < XL_STATS_WINDOW_TOP; t++) {
            if (!top[t] || slot->count > top[t]->count) {
                for (unsigned m = XL_STATS_WINDOW_TOP - 1; m > t; m--)
                    top[m] = top[m - 1];
                top[t] = slot;
                break;
            }
        }
    }
    for (unsigned t = 0; t < XL_STATS_WINDOW_TOP && top[t]; t++)
        dprintf(2, "xlate:   sent %c[%s %s] %u times, %llu us\n", class_isMetaClass((Class)top[t]->cls) ? '+' : '-',
                class_getName((Class)top[t]->cls), sel_getName((SEL)top[t]->sel), top[t]->count,
                (unsigned long long)xl_stats_us(top[t]->ticks));
    memset(xl_stats_window, 0, sizeof xl_stats_window);
    pthread_mutex_unlock(&xl_stats_lock);
}

static void xl_stats_message(uint64_t started, Class lookup, SEL selector)
{
    uint64_t ticks = mach_absolute_time() - started;
    pthread_mutex_lock(&xl_stats_lock);
    xl_stats_messages++;
    xl_stats_routing_ticks += ticks;
    xl_stats_window_note_locked(lookup, selector, ticks);
    pthread_mutex_unlock(&xl_stats_lock);
}

static void xl_stats_report_locked(void)
{
    const struct xl_stats_slot *top[XL_STATS_TOP] = {0};
    for (unsigned i = 0; i < XL_STATS_SLOTS; i++) {
        const struct xl_stats_slot *slot = &xl_stats_slots[i];
        if (!slot->count)
            continue;
        for (unsigned t = 0; t < XL_STATS_TOP; t++) {
            if (!top[t] || slot->ticks > top[t]->ticks) {
                for (unsigned m = XL_STATS_TOP - 1; m > t; m--)
                    top[m] = top[m - 1];
                top[t] = slot;
                break;
            }
        }
    }
    dprintf(2, "xlate: messages: %u in all, %u of them dynamic; routing %llu us in all (%llu us each), host call %llu us in the dynamic ones (%llu us each)\n",
            xl_stats_messages, xl_stats_dynamic, (unsigned long long)xl_stats_us(xl_stats_routing_ticks),
            (unsigned long long)xl_stats_us(xl_stats_routing_ticks) / (xl_stats_messages ? xl_stats_messages : 1),
            (unsigned long long)xl_stats_us(xl_stats_call_ticks),
            (unsigned long long)xl_stats_us(xl_stats_call_ticks) / (xl_stats_dynamic ? xl_stats_dynamic : 1));
    for (unsigned t = 0; t < XL_STATS_TOP && top[t]; t++)
        dprintf(2, "xlate:   dynamic %c[%s %s] %u times, %llu us\n", class_isMetaClass((Class)top[t]->cls) ? '+' : '-',
                class_getName((Class)top[t]->cls), sel_getName((SEL)top[t]->sel), top[t]->count,
                (unsigned long long)xl_stats_us(top[t]->ticks));
}

static void xl_stats_dynamic_send(uint64_t routing, uint64_t call, Class lookup, SEL selector)
{
    pthread_mutex_lock(&xl_stats_lock);
    xl_stats_messages++;
    xl_stats_dynamic++;
    xl_stats_routing_ticks += routing;
    xl_stats_call_ticks += call;
    xl_stats_window_note_locked(lookup, selector, routing + call);
    unsigned start = (unsigned)((((uintptr_t)selector >> 2) ^ ((uintptr_t)lookup >> 4)) * 2654435761u) % XL_STATS_SLOTS;
    for (unsigned probe = 0; probe < XL_STATS_SLOTS; probe++) {
        struct xl_stats_slot *slot = &xl_stats_slots[(start + probe) % XL_STATS_SLOTS];
        if (!slot->count) {
            slot->cls = (uintptr_t)lookup;
            slot->sel = (uintptr_t)selector;
        }
        if (slot->cls == (uintptr_t)lookup && slot->sel == (uintptr_t)selector) {
            slot->count++;
            slot->ticks += routing + call;
            break;
        }
    }
    if (xl_stats_dynamic == XL_STATS_FIRST || xl_stats_dynamic == XL_STATS_SECOND || xl_stats_dynamic % XL_STATS_EVERY == 0)
        xl_stats_report_locked();
    pthread_mutex_unlock(&xl_stats_lock);
}

struct xl_arguments {
    uint64_t words[(XL_OFFSET_X9 - XL_OFFSET_X0) / sizeof(uint64_t)];
    uint64_t vectors[(XL_OFFSET_V8 - XL_OFFSET_V0) / sizeof(uint64_t)];
};

static inline void xl_arguments_save(State *state, struct xl_arguments *saved)
{
    __builtin_memcpy_inline(saved->words, &XL_REG(state, X0), sizeof saved->words);
    __builtin_memcpy_inline(saved->vectors, &XL_REG(state, V0), sizeof saved->vectors);
}

static inline void xl_arguments_restore(State *state, const struct xl_arguments *saved)
{
    __builtin_memcpy_inline(&XL_REG(state, X0), saved->words, sizeof saved->words);
    __builtin_memcpy_inline(&XL_REG(state, V0), saved->vectors, sizeof saved->vectors);
}

static void xl_dynamic_send(State *state, id receiver, Method method, SEL selector, IMP forced);

static uint64_t xl_bridge_for(State *state, Class lookup, SEL selector, IMP imp, Method method, id receiver, Class super_class);

static uint64_t xl_route(State *state, Class lookup, SEL selector, id receiver, Class super_class)
{
    if (xl_selector_neutralized(selector) || xl_class_neutralized(lookup))
        return 0;
    IMP imp = class_getMethodImplementation(lookup, selector);
    uintptr_t guest = (uintptr_t)CFDictionaryGetValue(xl_guest_imps, imp);
    if (!guest)
        guest = xl_shadow_imp(imp);
    if (guest)
        return guest;
    return xl_bridge_for(state, lookup, selector, imp, NULL, receiver, super_class);
}

static uint64_t xl_bridge_for(State *state, Class lookup, SEL selector, IMP imp, Method method, id receiver, Class super_class)
{
    uintptr_t guest;
    if (imp) {
        pthread_mutex_lock(&xl_variant_lock);
        uintptr_t cached = (uintptr_t)CFDictionaryGetValue(xl_variant_cache, imp);
        pthread_mutex_unlock(&xl_variant_lock);
        if (cached)
            return cached;
    }
    CFMutableDictionaryRef by_enc = (CFMutableDictionaryRef)CFDictionaryGetValue(xl_selector_variant_table, selector);
    if (by_enc) {
        Method declared = method ? method : (lookup ? class_getInstanceMethod(lookup, selector) : NULL);
        const char *enc = declared ? method_getTypeEncoding(declared) : NULL;
        if (enc) {
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
                if (imp) {
                    pthread_mutex_lock(&xl_variant_lock);
                    CFDictionarySetValue(xl_variant_cache, imp, (void *)variant);
                    pthread_mutex_unlock(&xl_variant_lock);
                }
                return variant;
            }
            int miss_fd = xl_log_open("xlate-variant-miss.log");
            FILE *f = miss_fd >= 0 ? fdopen(miss_fd, "a") : NULL;
            if (f) {
                fprintf(f, "-[%s %s] enc=%s: no variant match, using default\n",
                        class_getName(lookup), sel_getName(selector), stripped);
                fclose(f);
            }
        }
    }
    guest = (uintptr_t)CFDictionaryGetValue(xl_selector_table, selector);
    if (!guest) {
        if (xl_log_enabled()) {
            uint32_t seen = xl_nobridge_seen(lookup, selector);
            if (seen <= XL_NOBRIDGE_FULL) {
                fprintf(stderr, "xlate: no bridge for -[%s %s], sent dynamically with the signature of the host method\n", class_getName(lookup), sel_getName(selector));
                if (seen == 1) {
                    int nb_fd = xl_log_open("xlate-nobridge.log");
                    FILE *nb = nb_fd >= 0 ? fdopen(nb_fd, "a") : NULL;
                    if (nb) {
                        fprintf(nb, "%c[%s %s]\n", class_isMetaClass(lookup) ? '+' : '-', class_getName(lookup), sel_getName(selector));
                        fclose(nb);
                    }
                }
                fprintf(stderr, "xlate:   receiver=%p isa=0x%x lookup=%p(%s) isMeta=%d imp=%p\n",
                        (void *)receiver, receiver ? *(uint32_t *)receiver : 0, (void *)lookup, class_getName(lookup),
                        class_isMetaClass(lookup), (void *)imp);
                xl_report_guest_frame();
            } else if (seen % XL_NOBRIDGE_EVERY == 0) {
                fprintf(stderr, "xlate: no bridge for -[%s %s]: %u messages so far, the next ones are not written one by one\n", class_getName(lookup), sel_getName(selector), seen);
            }
        }
        if (xl_collect_enabled()) {
            xl_collect_note("-[%s %s]\n", class_getName(lookup), sel_getName(selector));
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

static void xl_dynamic_fault(State *state, id receiver, SEL selector, const char *what, const char *detail)
{
    char message[320];
    snprintf(message, sizeof message, "message without a bridge (%s): -[%s %s], %s", what,
             class_getName(object_getClass(receiver)), sel_getName(selector), detail);
    xl_fault(state, message);
}

static int xl_selector_word_argument(SEL selector, unsigned index)
{
    const char *name = sel_getName(selector);
    if (!strcmp(name, "performSelector:withObject:"))
        return index == 1;
    if (!strcmp(name, "performSelector:withObject:withObject:"))
        return index == 1 || index == 2;
    return 0;
}

static void xl_dynamic_send(State *state, id receiver, Method method, SEL selector, IMP forced)
{
    if (!method) {
        if (forced)
            xl_fault(state, "call of an IMP whose method the runtime does not describe");
        ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    unsigned argc = method_getNumberOfArguments(method);
    uint32_t words[16] = {0};
    unsigned used = 2;
    unsigned next_integer = 2, next_vector = 0;
    words[0] = (uint32_t)(uintptr_t)receiver;
    words[1] = (uint32_t)(uintptr_t)selector;
    for (unsigned i = 2; i < argc; i++) {
        char *type = method_copyArgumentType(method, i);
        const char *t = type;
        while (*t == 'r' || *t == 'n' || *t == 'N' || *t == 'o' || *t == 'O' || *t == 'R' || *t == 'V')
            t++;
        if (*t == 'f' || *t == 'd') {
            unsigned need = *t == 'd' ? 2 : 1;
            if (next_vector >= 8 || used + need > 12) {
                char detail[96];
                snprintf(detail, sizeof detail, "argument %u of %u, encoding %s", i, argc, method_getTypeEncoding(method));
                free(type);
                xl_dynamic_fault(state, receiver, selector, "stack-passed arguments", detail);
            }
            uint64_t bits = *(uint64_t *)((char *)state + XL_OFFSET_V0 + 16 * next_vector++);
            words[used++] = (uint32_t)bits;
            if (need == 2)
                words[used++] = (uint32_t)(bits >> 32);
            free(type);
            continue;
        }
        if (next_integer >= 8 || used + ((*t == 'q' || *t == 'Q') ? 2 : 1) > 12) {
            char detail[96];
            snprintf(detail, sizeof detail, "argument %u of %u, encoding %s", i, argc, method_getTypeEncoding(method));
            free(type);
            xl_dynamic_fault(state, receiver, selector, "stack-passed arguments", detail);
        }
        uint64_t value = *(uint64_t *)((char *)state + XL_OFFSET_X0 + 8 * next_integer++);
        int wide = 0;
        uint32_t word = 0;
        switch (*t) {
        case '@':
            word = (uint32_t)(xl_selector_word_argument(selector, i - 2) ? xl_object_in_word(value, "dynamic message", i)
                                                                          : xl_object_in(value, "dynamic message", i));
            break;
        case '#': word = (uint32_t)(uintptr_t)xl_class_in(xl_narrow_pointer(value, "dynamic message", i)); break;
        case ':': case '^': case '*':
            word = (uint32_t)xl_narrow_pointer(value, "dynamic message", i);
            break;
        case 'c': case 'C': case 's': case 'S': case 'i': case 'I': case 'l': case 'L': case 'B':
            word = (uint32_t)value;
            break;
        case 'q': case 'Q': wide = 1; break;
        default: {
            char detail[96];
            snprintf(detail, sizeof detail, "argument %u has encoding %s", i, type);
            free(type);
            xl_dynamic_fault(state, receiver, selector, "argument type", detail);
        }
        }
        if (wide) {
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
    IMP imp = forced ? forced : method_getImplementation(method);
    typedef uintptr_t (*call32)(uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t,
                                uintptr_t, uintptr_t, uintptr_t, uintptr_t);
    typedef uint64_t (*call64)(uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t,
                               uintptr_t, uintptr_t, uintptr_t, uintptr_t);
    uint64_t result = 0;
    int floating = 0;
    uint64_t vector = 0;
    switch (*r) {
    case 'v': ((call32)imp)(words[0], words[1], words[2], words[3], words[4], words[5], words[6], words[7], words[8], words[9], words[10], words[11]); break;
    case 'f':
        floating = 1;
        vector = (uint32_t)((call32)imp)(words[0], words[1], words[2], words[3], words[4], words[5], words[6], words[7], words[8], words[9], words[10], words[11]);
        break;
    case 'd':
        floating = 1;
        vector = ((call64)imp)(words[0], words[1], words[2], words[3], words[4], words[5], words[6], words[7], words[8], words[9], words[10], words[11]);
        break;
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
    default: {
        char detail[96];
        snprintf(detail, sizeof detail, "result has encoding %s", ret);
        free(ret);
        xl_dynamic_fault(state, receiver, selector, "return type", detail);
    }
    }
    free(ret);
    if (floating) {
        xl_zero_result(state);
        *(uint64_t *)((char *)state + XL_OFFSET_V0) = vector;
        xl_return(state);
        return;
    }
    XL_REG(state, X0) = result;
    xl_return(state);
}

static struct xl_diag_flag xl_trace_flag = {"xl-trace", 0};
static struct xl_diag_flag xl_trace_rc_flag = {"xl-trace-rc", 0};
static pthread_once_t xl_trace_once = PTHREAD_ONCE_INIT;
static int xl_trace_fd = -1;

static void xl_trace_open(void)
{
    if (xl_diag_on(&xl_trace_flag))
        xl_trace_fd = xl_diag_open("xlate-msgtrace.log", O_APPEND);
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
        SEL bsel = (SEL)(uintptr_t)XL_REG(state, X1);
        uint64_t a2 = XL_REG(state, X2), a3 = XL_REG(state, X3), a4 = XL_REG(state, X4);
        struct xl_block_wrapper *w = xl_wrapper_for(self);
        id result = ((id (*)(id, SEL, uint64_t, uint64_t, uint64_t))objc_msgSend)((id)w, bsel, a2, a3, a4);
        objc_release((id)w);
        XL_REG(state, X0) = xl_object_out((uintptr_t)result);
        xl_return(state);
        return;
    }
    uint64_t stats_started = xl_stats_enabled() ? mach_absolute_time() : 0;
    id receiver = (id)xl_narrow_pointer(self, "objc_msgSend", 0);
    SEL selector = (SEL)(uintptr_t)XL_REG(state, X1);
    pthread_once(&xl_trace_once, xl_trace_open);
    int trace_flags = xl_trace_fd >= 0 ? 1 | (xl_diag_on(&xl_trace_rc_flag) ? 2 : 0) : 0;
    if (trace_flags & 1) {
        int xl_tfd = xl_trace_fd;
        if (xl_tfd >= 0) {
            const char *sn = sel_getName(selector);
            static int xl_nf = -1;
            if (xl_nf < 0) xl_nf = open("/dev/null", O_WRONLY);
            const char *state_s = "UNMAPPED";
            char cls[128]; cls[0] = 0;
            if (receiver && xl_nf >= 0 && write(xl_nf, (void *)receiver, 4) == 4) {
                state_s = "mapped";
                uint32_t isa = *(uint32_t *)(uintptr_t)receiver;
                if (isa && write(xl_nf, (void *)(uintptr_t)isa, 4) == 4) {
                    const char *cn = xl_journal_class_name(isa);
                    if (trace_flags & 2) {
                        long rc = (cn[0] == '?' || cn[0] == 'u') ? -2 : class_isMetaClass((Class)(uintptr_t)isa) ? -1 : CFGetRetainCount((CFTypeRef)receiver);
                        snprintf(cls, sizeof cls, " isa=0x%x class=%s rc=%ld", isa, cn ? cn : "?", rc);
                    } else {
                        snprintf(cls, sizeof cls, " isa=0x%x class=%s", isa, cn ? cn : "?");
                    }
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
            if (sn && (!strcmp(sn, "stringWithFormat:") || !strcmp(sn, "errorWithDomain:code:userInfo:"))) {
                id arg = (id)xl_object_in(XL_REG(state, X2), "trace", 0);
                if (arg && [arg isKindOfClass:[NSString class]]) {
                    char tl[600];
                    int tn;
                    if (!strcmp(sn, "stringWithFormat:")) {
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
            if (sn && state_s[0] == 'm' && (!strcmp(sn, "fileSystemRepresentation") || !strcmp(sn, "path")) &&
                strstr(cls, "NSURL")) {
                id v = ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
                const char *u = !strcmp(sn, "path") ? [(NSString *)v UTF8String] : (const char *)v;
                char tl[600];
                int tn = snprintf(tl, sizeof tl, "    -> %s = [%s]\n", sn, u ? u : "(nil)");
                if (tn > (int)sizeof tl) tn = (int)sizeof tl;
                write(xl_tfd, tl, tn);
            }
            if (sn && state_s[0] == 'm' && !strcmp(sn, "callStackReturnAddresses") && strstr(cls, "NSException")) {
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
    struct xl_arguments arguments;
    xl_arguments_save(state, &arguments);
    Class receiver_class = xl_class_of(receiver);
    if (xl_class_neutralized(receiver_class) || xl_selector_neutralized(selector)) {
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    void (*variadic)(State *) = (void (*)(State *))CFDictionaryGetValue(xl_variadic_table, selector);
    if (variadic) {
        xl_arguments_restore(state, &arguments);
        variadic(state);
        return;
    }
    uint64_t target = xl_route(state, receiver_class, selector, receiver, Nil);
    if (xl_shadow_log_enabled())
        xl_shadow_note("msg %p %s: isa %x, class %p (%s), target %llx", (void *)receiver, sel_getName(selector),
                       receiver ? *(uint32_t *)receiver : 0, receiver_class, class_getName(receiver_class), (unsigned long long)target);
    if (target == XL_NO_BRIDGE) {
        id host_receiver = (id)xl_receiver_in((uintptr_t)receiver);
        Method method = class_getInstanceMethod(receiver_class, selector);
        xl_arguments_restore(state, &arguments);
        if (stats_started) {
            uint64_t called = mach_absolute_time();
            xl_dynamic_send(state, host_receiver, method, selector, NULL);
            uint64_t returned = mach_absolute_time();
            xl_stats_dynamic_send(called - stats_started, returned - called, receiver_class, selector);
            return;
        }
        xl_dynamic_send(state, host_receiver, method, selector, NULL);
        return;
    }
    xl_arguments_restore(state, &arguments);
    if (!target) {
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    if (stats_started)
        xl_stats_message(stats_started, receiver_class, selector);
    XL_REG(state, PC) = target;
    [[clang::musttail]] return xl_tail(state);
}

void xl_h_objc_msgSendSuper2(State *state)
{
    struct xl_arguments arguments;
    xl_arguments_save(state, &arguments);
    uint64_t *guest_super = (uint64_t *)xl_narrow_pointer(XL_REG(state, X0), "objc_msgSendSuper2", 0);
    uint64_t guest_receiver = guest_super[0];
    id receiver = (id)xl_narrow_pointer(guest_receiver, "objc_msgSendSuper2", 1);
    Class current = xl_class_in(guest_super[1]);
    SEL selector = (SEL)(uintptr_t)XL_REG(state, X1);
    if (selector == @selector(dealloc))
        xl_swift_super_dealloc(receiver, current);
    uint64_t target = xl_route(state, class_getSuperclass(current), selector, receiver, current);
    xl_arguments_restore(state, &arguments);
    XL_REG(state, X0) = guest_receiver;
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
    if (xl_collect_enabled()) {
        xl_collect_note("C %s\n", message);
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

+ (instancetype)newWithGuestBlock:(uint64_t)guest
{
    XLGuestBlock *holder = [[self alloc] init];
    holder->_guestBlock = xl_invoke(XL_GUEST__Block_copy, guest);
    return holder;
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

#define XL_ITEMS_SLOTS 32

static struct {
    uint64_t state;
    uint64_t *items;
} xl_items_slots[XL_ITEMS_SLOTS];
static unsigned xl_items_next;
static pthread_mutex_t xl_items_lock = PTHREAD_MUTEX_INITIALIZER;

static uint64_t *xl_items_buffer(uint64_t state, NSUInteger count)
{
    pthread_mutex_lock(&xl_items_lock);
    unsigned slot = XL_ITEMS_SLOTS;
    for (unsigned i = 0; i < XL_ITEMS_SLOTS; i++) {
        if (xl_items_slots[i].state == state) {
            slot = i;
            break;
        }
    }
    if (slot == XL_ITEMS_SLOTS) {
        if (!count) {
            pthread_mutex_unlock(&xl_items_lock);
            return NULL;
        }
        slot = xl_items_next++ % XL_ITEMS_SLOTS;
    }
    free(xl_items_slots[slot].items);
    xl_items_slots[slot].items = NULL;
    xl_items_slots[slot].state = 0;
    uint64_t *items = NULL;
    if (count) {
        items = malloc(count * sizeof(uint64_t));
        if (!items) {
            pthread_mutex_unlock(&xl_items_lock);
            xl_unsupported("fast enumeration: no memory for the item list of a guest enumeration state");
        }
        xl_items_slots[slot].state = state;
        xl_items_slots[slot].items = items;
    }
    pthread_mutex_unlock(&xl_items_lock);
    return items;
}

void xl_manual_fast_enumeration(void *pack)
{
    struct xl_fast_enumeration_pack *p = pack;
    struct xl_guest_enumeration *guest = (struct xl_guest_enumeration *)xl_narrow_pointer(p->state, "countByEnumeratingWithState:objects:count:", 0);
    NSFastEnumerationState *host = (NSFastEnumerationState *)&guest->extra[0];
    id buffer[16];
    NSUInteger length = p->length < 16 ? (NSUInteger)p->length : 16;
    id enumerated = (id)xl_object_in(p->self, "countByEnumeratingWithState:objects:count:", 0);
    NSUInteger count = [enumerated countByEnumeratingWithState:host objects:buffer count:length];
    uint64_t *items = xl_items_buffer(p->state, count);
    if (count) {
        for (NSUInteger i = 0; i < count; i++)
            items[i] = xl_object_out((uintptr_t)host->itemsPtr[i]);
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

void xl_manual_init_with_format_arguments(void *pack)
{
    struct xl_init_format_pack *p = pack;
    struct xl_format format;
    xl_format_marshal_valist(&format, 0, (void *)xl_object_in(p->format, "initWithFormat:arguments:", 0), p->arguments,
                             "initWithFormat:arguments:");
    id result = [(id)xl_object_in(p->self, "initWithFormat:arguments:", 0) initWithFormat:(NSString *)format.object arguments:(va_list)format.arguments];
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
    p->r = xl_object_out((uintptr_t)objc_initWeak(slot, (id)xl_object_in_raw(p->a1, "objc_initWeak", 1)));
}

void xl_manual_objc_storeWeak(struct xl_weak_pack *p)
{
    p->r = xl_object_out((uintptr_t)objc_storeWeak(xl_weak_slot(p->a0), (id)xl_object_in_raw(p->a1, "objc_storeWeak", 1)));
}

void xl_manual_objc_destroyWeak(struct xl_weak_pack1 *p)
{
    objc_destroyWeak(xl_weak_slot(p->a0));
}

void xl_manual_objc_loadWeakRetained(struct xl_weak_pack1 *p)
{
    p->r = xl_object_out((uintptr_t)objc_loadWeakRetained(xl_weak_slot(p->a0)));
}

void xl_manual_objc_loadWeak(struct xl_weak_pack1 *p)
{
    p->r = xl_object_out((uintptr_t)objc_loadWeak(xl_weak_slot(p->a0)));
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

extern void *_NSConcreteMallocBlock;

struct xl_block_desc {
    unsigned long reserved;
    unsigned long size;
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
    const char *signature;
};

#define XL_BLOCK_KINDS 8

struct xl_block_wrapper {
    void *isa;
    volatile int32_t flags;
    int32_t reserved;
    void *invoke;
    struct xl_block_desc *descriptor;
    uint64_t guest;
    char kinds[XL_BLOCK_KINDS];
    char result;
    char count;
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

static char xl_type_token(const char **p, int host_side)
{
    while (**p == 'r' || **p == 'n' || **p == 'N' || **p == 'o' || **p == 'O' || **p == 'R' || **p == 'V')
        (*p)++;
    char c = **p;
    switch (c) {
    case 'v': (*p)++; return 'V';
    case 'f': (*p)++; return host_side ? 'X' : 'F';
    case 'd': (*p)++; return host_side ? 'X' : 'D';
    case 'q': (*p)++; return host_side ? 'X' : 'S';
    case 'Q': (*p)++; return host_side ? 'X' : 'U';
    case 'c': case 'i': case 's': case 'l':
    case 'C': case 'I': case 'S': case 'L': case 'B': (*p)++; return 'I';
    case '@':
        (*p)++;
        if (**p == '?') (*p)++;
        else if (**p == '"') { (*p)++; while (**p && **p != '"') (*p)++; if (**p == '"') (*p)++; }
        return 'O';
    case '#': (*p)++; return 'K';
    case ':': case '*': (*p)++; return 'P';
    case '^': (*p)++; xl_type_token(p, host_side); return 'P';
    default: return 'X';
    }
}

static int xl_block_simple_args(const char *sig, char *kinds, char *result, int host_side)
{
    if (!sig)
        return -1;
    const char *p = sig;
    char ret = xl_type_token(&p, host_side);
    if (ret == 'X')
        return -1;
    *result = ret;
    while (*p >= '0' && *p <= '9') p++;
    char self_kind = xl_type_token(&p, host_side);
    if (self_kind != 'O' && self_kind != 'P' && self_kind != 'K')
        return -1;
    while (*p >= '0' && *p <= '9') p++;
    int count = 0;
    int limit = host_side ? 4 : XL_BLOCK_KINDS;
    int words = 0;
    while (*p) {
        char t = xl_type_token(&p, host_side);
        if (t == 'X' || t == 'V')
            return -1;
        while (*p >= '0' && *p <= '9') p++;
        if (count < limit)
            kinds[count] = t;
        count++;
        words += t == 'D' ? 2 : 1;
    }
    return count > limit || words > XL_BLOCK_KINDS ? -1 : count;
}

static uintptr_t xl_block_call(struct xl_block_wrapper *w, const uint64_t *args, unsigned n)
{
    uint64_t invoke = *(uint64_t *)(uintptr_t)(w->guest + 16);
    uint64_t all[5];
    all[0] = w->guest;
    for (unsigned i = 0; i < n; i++)
        all[i + 1] = xl_kind_out(w->kinds[i], (uintptr_t)args[i]);
    return xl_kind_in(w->result, xl_invoke_n(invoke, all, n + 1), "guest block result");
}

static uintptr_t xl_block_t0(void *b) { return xl_block_call(b, 0, 0); }
static uintptr_t xl_block_t1(void *b, uintptr_t a0) { uint64_t a[1] = {a0}; return xl_block_call(b, a, 1); }
static uintptr_t xl_block_t2(void *b, uintptr_t a0, uintptr_t a1) { uint64_t a[2] = {a0, a1}; return xl_block_call(b, a, 2); }
static uintptr_t xl_block_t3(void *b, uintptr_t a0, uintptr_t a1, uintptr_t a2) { uint64_t a[3] = {a0, a1, a2}; return xl_block_call(b, a, 3); }
static uintptr_t xl_block_t4(void *b, uintptr_t a0, uintptr_t a1, uintptr_t a2, uintptr_t a3) { uint64_t a[4] = {a0, a1, a2, a3}; return xl_block_call(b, a, 4); }
uint64_t xl_invoke_typed(uint64_t address, const uint64_t *lead, unsigned lead_count, const char *kinds, unsigned count, const uintptr_t *words, char result_kind)
{
    uint64_t integers[8], floats[8];
    unsigned integer_count = 0, float_count = 0, word = 0;
    for (; integer_count < lead_count && integer_count < 8; integer_count++)
        integers[integer_count] = lead[integer_count];
    for (unsigned i = 0; i < count; i++) {
        char kind = kinds[i];
        if (kind == 'F' || kind == 'D') {
            if (float_count == 8)
                xl_unsupported("a host call into the guest passes more than eight floating-point arguments");
            floats[float_count++] = kind == 'F' ? (uint64_t)(uint32_t)words[word] : ((uint64_t)(uint32_t)words[word] | (uint64_t)(uint32_t)words[word + 1] << 32);
            word += kind == 'D' ? 2 : 1;
        } else {
            if (integer_count == 8)
                xl_unsupported("a host call into the guest passes more than eight integer arguments");
            integers[integer_count++] = xl_kind_out(kind, words[word++]);
        }
    }
    uint64_t vector = 0;
    uint64_t result = xl_invoke_registers(address, integers, integer_count, floats, float_count, &vector);
    if (result_kind == 'F')
        return (uint32_t)vector;
    return result_kind == 'D' ? vector : result;
}

static uint64_t xl_block_tf(void *b, uintptr_t a0, uintptr_t a1, uintptr_t a2, uintptr_t a3, uintptr_t a4, uintptr_t a5, uintptr_t a6, uintptr_t a7)
{
    struct xl_block_wrapper *w = b;
    const uintptr_t words[8] = {a0, a1, a2, a3, a4, a5, a6, a7};
    const uint64_t lead[1] = {w->guest};
    uint64_t result = xl_invoke_typed(*(uint64_t *)(uintptr_t)(w->guest + 16), lead, 1, w->kinds, (unsigned)w->count, words, w->result);
    if (w->result == 'F' || w->result == 'D')
        return result;
    return xl_kind_in(w->result, result, "guest block result");
}

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

struct xl_host_block_layout {
    void *isa;
    int32_t flags;
    int32_t reserved;
    void *invoke;
    const uintptr_t *descriptor;
};

static const char *xl_host_block_signature(const struct xl_host_block_layout *block)
{
    if (!(block->flags & XL_BLOCK_HAS_SIGNATURE) || !block->descriptor)
        return NULL;
    return (const char *)block->descriptor[(block->flags & XL_BLOCK_HAS_COPY_DISPOSE) ? 4 : 2];
}

struct __attribute__((packed)) xl_hblock_generic_pack {
    uint64_t host, a0, a1, a2, a3, r;
};

void xl_manual_hblock_generic(void *pack)
{
    struct xl_hblock_generic_pack *p = pack;
    const struct xl_host_block_layout *block = (const struct xl_host_block_layout *)(uintptr_t)p->host;
    const char *signature = xl_host_block_signature(block);
    char kinds[4], result = 'V';
    int count = xl_block_simple_args(signature, kinds, &result, 1);
    if (count < 0) {
        char why[256];
        snprintf(why, sizeof why, "xlate: a host block that the guest calls has %s%s, which the bridge cannot marshal (up to four arguments, each an object, a pointer or a 32-bit integer)",
                 signature ? "the signature " : "no signature", signature ? signature : "");
        xl_unsupported(why);
    }
    const uint64_t arguments[4] = {p->a0, p->a1, p->a2, p->a3};
    uintptr_t words[4] = {0, 0, 0, 0};
    for (int i = 0; i < count; i++)
        words[i] = xl_kind_in(kinds[i], arguments[i], "host block argument");
    uintptr_t returned = ((uintptr_t (*)(const void *, uintptr_t, uintptr_t, uintptr_t, uintptr_t))block->invoke)(block, words[0], words[1], words[2], words[3]);
    p->r = result == 'V' ? 0 : xl_kind_out(result, returned);
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
    int args = xl_block_simple_args(xl_guest_block_signature(guest), w->kinds, &w->result, 0);
    w->count = (char)args;
    int floating = w->result == 'F' || w->result == 'D';
    for (int i = 0; i < args; i++)
        floating |= w->kinds[i] == 'F' || w->kinds[i] == 'D';
    switch (args >= 0 && (floating || args > 4) ? 5 : args) {
    case 5: w->invoke = (void *)xl_block_tf; break;
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

uintptr_t xl_object_in_raw(uint64_t guest, const char *symbol, unsigned index)
{
    if (guest && guest < 0x4000) {
        fprintf(stderr, "xlate: %s argument %u is 0x%llx, not an object pointer\n", symbol, index, guest);
        xl_report_guest_frame();
        abort();
    }
    if (!xl_is_guest_block(guest))
        return (uintptr_t)xl_class_in(xl_narrow_pointer(guest, symbol, index));
    return (uintptr_t)objc_autorelease((id)xl_wrapper_for(guest));
}

uintptr_t xl_object_in(uint64_t guest, const char *symbol, unsigned index)
{
    if (guest && guest < 0x4000) {
        fprintf(stderr, "xlate: %s argument %u is 0x%llx, not an object pointer\n", symbol, index, guest);
        xl_report_guest_frame();
        abort();
    }
    if (xl_is_guest_block(guest))
        return (uintptr_t)objc_autorelease((id)xl_wrapper_for(guest));
    uintptr_t narrowed = xl_narrow_pointer(guest, symbol, index);
    uintptr_t proxy = xl_proxy_in(narrowed);
    return proxy ? proxy : (uintptr_t)xl_class_in(narrowed);
}

uintptr_t xl_object_in_owned(uint64_t guest, const char *symbol, unsigned index)
{
    return xl_proxy_owned(xl_object_in(guest, symbol, index));
}

int xl_selector_returns_owned(const char *name)
{
    static const char *const families[] = {"alloc", "new", "copy", "mutableCopy"};
    while (*name == '_')
        name++;
    for (size_t i = 0; i < sizeof families / sizeof *families; i++) {
        size_t length = strlen(families[i]);
        if (strncmp(name, families[i], length) == 0 && !(name[length] >= 'a' && name[length] <= 'z'))
            return 1;
    }
    return 0;
}

uint64_t xl_object_out(uintptr_t host)
{
    if (host - xl_word_low < xl_word_span)
        return xl_word_value(host);
    struct xl_block_wrapper *w = xl_wrapper_of(host);
    if (w)
        return w->guest;
    uint64_t proxied = xl_proxy_out(host);
    if (proxied)
        return proxied;
    if ((host & 7) == 4) {
        uint64_t alias = xl_alias_object(host);
        if (alias)
            return alias;
    }
    return xl_class_out(host);
}

uintptr_t xl_object_in_word(uint64_t guest, const char *symbol, unsigned index)
{
    if (guest < 0x4000)
        return (uintptr_t)guest;
    if ((guest >> 32) && guest < 0xFFFFFFFFFFFFFF00ull)
        return xl_word_slot(guest, symbol, index);
    return xl_object_in(guest, symbol, index);
}

uint64_t xl_object_out_word(uintptr_t host)
{
    if (host < 0x4000)
        return host;
    return xl_object_out(host);
}

void *xl_fast_items(uint64_t items, uint64_t count)
{
    if (!items || !count)
        return 0;
    const uint64_t *guest = (const uint64_t *)xl_narrow_pointer(items, "fast enumeration items", 0);
    id *host = (id *)[[NSMutableData dataWithLength:(NSUInteger)count * sizeof(id)] mutableBytes];
    for (uint64_t i = 0; i < count; i++)
        host[i] = (id)xl_object_in(guest[i], "fast enumeration item", (unsigned)i);
    return host;
}

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
    guest = xl_narrow_pointer(guest, "protocol", 0);
    const char *name = (const char *)xl_narrow_pointer(*(uint32_t *)(uintptr_t)(guest + 4), "protocol name", 0);
    return name ? (uintptr_t)objc_getProtocol(name) : 0;
}

static uint64_t xl_variadic_arg(State *state, unsigned index)
{
    if (index == 0)
        return XL_REG(state, X2);
    uint64_t sp = XL_REG(state, SP);
    return *(uint64_t *)(uintptr_t)xl_narrow_pointer(sp + 8 * (index - 1), "variadic argument", index);
}

void xl_h_dictionaryWithObjectsAndKeys(State *state)
{
    id self = (id)xl_object_in(XL_REG(state, X0), "dictionaryWithObjectsAndKeys:", 0);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (unsigned i = 0;; i += 2) {
        uint64_t value = xl_variadic_arg(state, i);
        if (!value)
            break;
        uint64_t key = xl_variadic_arg(state, i + 1);
        if (!key)
            break;
        [dict setObject:(id)xl_object_in(value, "dictionaryWithObjectsAndKeys:", i + 2) forKey:(id)xl_object_in(key, "dictionaryWithObjectsAndKeys:", i + 3)];
    }
    id result = [self isKindOfClass:object_getClass([NSMutableDictionary class])] ? dict : [[dict copy] autorelease];
    XL_REG(state, X0) = xl_object_out((uintptr_t)result);
    xl_return(state);
}

static void xl_collect_objects(State *state, NSMutableArray *array, const char *symbol)
{
    for (unsigned i = 0;; i++) {
        uint64_t value = xl_variadic_arg(state, i);
        if (!value)
            break;
        [array addObject:(id)xl_object_in(value, symbol, i + 2)];
    }
}

void xl_h_arrayWithObjects(State *state)
{
    NSMutableArray *array = [NSMutableArray array];
    xl_collect_objects(state, array, "arrayWithObjects:");
    XL_REG(state, X0) = xl_object_out((uintptr_t)[[array copy] autorelease]);
    xl_return(state);
}

void xl_h_initWithObjects(State *state)
{
    id self = (id)xl_object_in(XL_REG(state, X0), "initWithObjects:", 0);
    NSMutableArray *array = [NSMutableArray array];
    xl_collect_objects(state, array, "initWithObjects:");
    id result = [self initWithArray:array];
    XL_REG(state, X0) = xl_object_out((uintptr_t)result);
    xl_return(state);
}

void xl_h_setWithObjects(State *state)
{
    NSMutableArray *array = [NSMutableArray array];
    xl_collect_objects(state, array, "setWithObjects:");
    XL_REG(state, X0) = xl_object_out((uintptr_t)[NSSet setWithArray:array]);
    xl_return(state);
}

struct __attribute__((packed)) xl_arc_pack {
    uint64_t a0;
    uint64_t r;
};

static void xl_arc_trace(uint64_t obj, const char *op);

static uintptr_t xl_host_retain(uint64_t guest, const char *symbol)
{
    xl_arc_trace(guest, symbol);
    id object = (id)xl_narrow_pointer(guest, symbol, 0);
    uint64_t result;
    return xl_guest_send(object, @selector(retain), &result) ? (uintptr_t)result : (uintptr_t)objc_retain(object);
}

static uintptr_t xl_host_autorelease(uint64_t guest, const char *symbol)
{
    xl_arc_trace(guest, symbol);
    id object = (id)xl_narrow_pointer(guest, symbol, 0);
    uint64_t result;
    return xl_guest_send(object, @selector(autorelease), &result) ? (uintptr_t)result : (uintptr_t)objc_autorelease(object);
}

static void xl_host_release(uint64_t guest, const char *symbol)
{
    xl_arc_trace(guest, symbol);
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

void xl_manual_objc_retainBlock(struct xl_arc_pack *p)
{
    p->r = (p->a0 && xl_is_guest_block(p->a0)) ? xl_block_retain(p->a0) : p->a0;
}

static void xl_arc_trace(uint64_t obj, const char *op)
{
    if (!xl_journal_enabled())
        return;
    uintptr_t pointer = (uintptr_t)obj;
    xl_journal_note(op, pointer, pointer >= 0x1000 && pointer < 0xFFFFF000u ? malloc_size((const void *)pointer) : 0);
}

struct __attribute__((packed)) xl_pool_push_pack {
    uint64_t r;
};

void xl_manual_objc_autoreleasePoolPush(struct xl_pool_push_pack *p)
{
    void *token = objc_autoreleasePoolPush();
    xl_journal_note("pool-push", (uintptr_t)token, 0);
    p->r = xl_widen_pointer((uintptr_t)token);
}

void xl_manual_objc_autoreleasePoolPop(struct xl_arc_pack *p)
{
    void *token = (void *)xl_narrow_pointer(p->a0, "objc_autoreleasePoolPop", 0);
    if (xl_journal_enabled())
        xl_journal_pool_pop((uintptr_t)token);
    objc_autoreleasePoolPop(token);
}

struct __attribute__((packed)) xl_allocate_pack {
    uint64_t a0;
    uint64_t a1;
    uint64_t a2;
    uint64_t r;
};

void xl_manual_NSAllocateObject(struct xl_allocate_pack *p)
{
    id object = NSAllocateObject((Class)xl_object_in((uint64_t)p->a0, "NSAllocateObject", 0),
                                 (unsigned int)xl_narrow_unsigned((uint64_t)p->a1, (uint64_t)((1ull << 32) - 1), UINT64_MAX, "NSAllocateObject", 1),
                                 (struct _NSZone *)xl_narrow_pointer((uint64_t)p->a2, "NSAllocateObject", 2));
    xl_journal_note("alloc-object", (uintptr_t)object, (uintptr_t)p->a1);
    p->r = xl_object_out((uintptr_t)object);
}

void xl_manual_object_dispose(struct xl_arc_pack *p)
{
    id object = (id)xl_object_in((uint64_t)p->a0, "object_dispose", 0);
    if (xl_journal_enabled())
        xl_journal_note("object-dispose", (uintptr_t)object, (uintptr_t)malloc_size((const void *)object));
    p->r = xl_object_out((uintptr_t)object_dispose(object));
}

struct __attribute__((packed)) xl_create_pack {
    uint64_t a0;
    uint64_t a1;
    uint64_t r;
};

void xl_manual_class_createInstance(struct xl_create_pack *p)
{
    id object = class_createInstance((Class)xl_object_in((uint64_t)p->a0, "class_createInstance", 0),
                                     (unsigned long)xl_narrow_unsigned((uint64_t)p->a1, (uint64_t)((1ull << 32) - 1), UINT64_MAX, "class_createInstance", 1));
    xl_journal_note("create-instance", (uintptr_t)object, (uintptr_t)p->a1);
    p->r = xl_object_out((uintptr_t)object);
}

uint32_t xl_guest_imp_address(IMP imp)
{
    uintptr_t guest = imp ? (uintptr_t)CFDictionaryGetValue(xl_guest_imps, imp) : 0;
    return (uint32_t)(guest ? guest : xl_shadow_imp(imp));
}

#define XL_IMP_SLOTS 4096

struct xl_imp_slot {
    IMP imp;
    SEL selector;
    Method method;
    Class cls;
    unsigned next;
};

static uint32_t xl_imp_region[XL_IMP_SLOTS];
static struct xl_imp_slot xl_imp_slots[XL_IMP_SLOTS];
static unsigned xl_imp_used;
static CFMutableDictionaryRef xl_imp_first;
static pthread_mutex_t xl_imp_lock = PTHREAD_MUTEX_INITIALIZER;

static struct xl_imp_slot *xl_imp_slot_at(uint64_t address)
{
    uint64_t base = (uintptr_t)xl_imp_region;
    if (address < base || address >= base + sizeof xl_imp_region || (address - base) % sizeof xl_imp_region[0])
        return NULL;
    unsigned index = (unsigned)((address - base) / sizeof xl_imp_region[0]);
    return index < __atomic_load_n(&xl_imp_used, __ATOMIC_ACQUIRE) ? &xl_imp_slots[index] : NULL;
}

static uint64_t xl_imp_out(IMP imp, Class cls, SEL selector, Method method)
{
    if (!imp)
        return 0;
    uint32_t guest = xl_guest_imp_address(imp);
    if (!guest)
        guest = xl_guest_function_of(imp);
    if (guest)
        return guest;
    pthread_mutex_lock(&xl_imp_lock);
    if (!xl_imp_first)
        xl_imp_first = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    unsigned head = (unsigned)(uintptr_t)CFDictionaryGetValue(xl_imp_first, imp);
    unsigned found = 0;
    for (unsigned at = head; at && !found; at = xl_imp_slots[at - 1].next)
        found = xl_imp_slots[at - 1].selector == selector ? at : 0;
    if (!found) {
        if (xl_imp_used == XL_IMP_SLOTS) {
            pthread_mutex_unlock(&xl_imp_lock);
            xl_unsupported("xlate: more than 4096 distinct implementations were handed to the guest");
        }
        found = xl_imp_used + 1;
        xl_imp_slots[found - 1] = (struct xl_imp_slot){imp, selector, method, cls, head};
        CFDictionarySetValue(xl_imp_first, imp, (void *)(uintptr_t)found);
        __atomic_store_n(&xl_imp_used, found, __ATOMIC_RELEASE);
    }
    pthread_mutex_unlock(&xl_imp_lock);
    return (uintptr_t)&xl_imp_region[found - 1];
}

static IMP xl_imp_in(uint64_t guest, SEL selector, const char *types)
{
    if (!guest)
        return NULL;
    struct xl_imp_slot *slot = xl_imp_slot_at(guest);
    return slot ? slot->imp : xl_host_imp_for_guest(guest, selector, types);
}

static IMP xl_imp_host(uint64_t guest)
{
    struct xl_imp_slot *slot = xl_imp_slot_at(guest);
    return slot ? slot->imp : NULL;
}

static void xl_imp_entry(State *state)
{
    struct xl_imp_slot *slot = xl_imp_slot_at(XL_REG(state, PC));
    if (!slot->selector)
        xl_fault(state, "call of an implementation that imp_implementationWithBlock made: it has no selector to marshal by");
    id receiver = (id)xl_narrow_pointer(XL_REG(state, X0), "IMP", 0);
    void (*variadic)(State *) = (void (*)(State *))CFDictionaryGetValue(xl_variadic_table, slot->selector);
    if (variadic) {
        variadic(state);
        return;
    }
    struct xl_arguments arguments;
    xl_arguments_save(state, &arguments);
    uint64_t target = xl_bridge_for(state, slot->cls, slot->selector, slot->imp, slot->method, receiver, Nil);
    if (target == XL_NO_BRIDGE) {
        id host_receiver = (id)xl_receiver_in((uintptr_t)receiver);
        xl_arguments_restore(state, &arguments);
        xl_dynamic_send(state, host_receiver, slot->method, slot->selector, slot->imp);
        return;
    }
    xl_arguments_restore(state, &arguments);
    if (!target) {
        xl_zero_result(state);
        xl_return(state);
        return;
    }
    pthread_setspecific(xl_imp_key, slot->imp);
    XL_REG(state, PC) = target;
    xl_call(state);
    pthread_setspecific(xl_imp_key, NULL);
}

#define XL_FUNCTION_SLOTS 32

struct xl_function_slot {
    void *host;
    const char *name;
    const char *shape;
};

static uint64_t xl_function_region[XL_FUNCTION_SLOTS];
static struct xl_function_slot xl_function_slots[XL_FUNCTION_SLOTS];
static unsigned xl_function_used;
static pthread_mutex_t xl_function_lock = PTHREAD_MUTEX_INITIALIZER;

static const struct {
    const char *name;
    const char *shape;
} xl_host_functions[] = {
    {"CFStringGetTypeID", "u"},
    {"CFGetTypeID", "u:o"},
    {"CFStringHashNSString", "u:o"},
    {"CFStringHashCString", "u:pl"},
    {NULL, NULL}
};

static struct xl_function_slot *xl_function_slot_at(uint64_t address)
{
    uint64_t base = (uintptr_t)xl_function_region;
    if (address < base || address >= base + sizeof xl_function_region || (address - base) % sizeof xl_function_region[0])
        return NULL;
    unsigned index = (unsigned)((address - base) / sizeof xl_function_region[0]);
    return index < __atomic_load_n(&xl_function_used, __ATOMIC_ACQUIRE) ? &xl_function_slots[index] : NULL;
}

static void *xl_guest_dlsym_find(const char *symbol)
{
    unsigned low = 0, high = xl_guest_dlsym_count;
    while (low < high) {
        unsigned middle = low + (high - low) / 2;
        int order = strcmp(symbol, xl_guest_dlsym_names + xl_guest_dlsym_offsets[middle]);
        if (!order)
            return (void *)(uintptr_t)xl_guest_dlsym_addresses[middle];
        if (order < 0)
            high = middle;
        else
            low = middle + 1;
    }
    return NULL;
}

static int xl_host_code_address(const void *address)
{
    Dl_info info;
    if (!dladdr(address, &info) || !info.dli_fbase)
        return 0;
    const struct mach_header *header = info.dli_fbase;
    if (header->magic != MH_MAGIC)
        return 0;
    const struct load_command *command = (const struct load_command *)(header + 1);
    uintptr_t slide = 0;
    for (uint32_t index = 0; index < header->ncmds; index++, command = (const struct load_command *)((const char *)command + command->cmdsize)) {
        if (command->cmd == LC_SEGMENT && strcmp(((const struct segment_command *)command)->segname, "__TEXT") == 0) {
            slide = (uintptr_t)header - ((const struct segment_command *)command)->vmaddr;
            break;
        }
    }
    uintptr_t target = (uintptr_t)address & ~(uintptr_t)1;
    command = (const struct load_command *)(header + 1);
    for (uint32_t index = 0; index < header->ncmds; index++, command = (const struct load_command *)((const char *)command + command->cmdsize)) {
        if (command->cmd != LC_SEGMENT)
            continue;
        const struct segment_command *segment = (const struct segment_command *)command;
        const struct section *section = (const struct section *)(segment + 1);
        for (uint32_t at = 0; at < segment->nsects; at++, section++) {
            uintptr_t start = section->addr + slide;
            if (target >= start && target - start < section->size)
                return (section->flags & (S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS)) != 0;
        }
    }
    return 0;
}

void *xl_shim_dlsym(void *handle, const char *symbol)
{
    if (symbol && (handle == RTLD_DEFAULT || handle == RTLD_NEXT || handle == RTLD_SELF)) {
        void *guest = xl_guest_dlsym_find(symbol);
        if (guest)
            return guest;
    }
    void *found = dlsym(handle, symbol);
    if (!found || !symbol)
        return found;
    for (unsigned entry = 0; xl_host_functions[entry].name; entry++) {
        if (strcmp(xl_host_functions[entry].name, symbol))
            continue;
        pthread_mutex_lock(&xl_function_lock);
        unsigned slot = 0;
        for (unsigned at = 0; at < xl_function_used && !slot; at++)
            slot = xl_function_slots[at].host == found ? at + 1 : 0;
        if (!slot) {
            if (xl_function_used == XL_FUNCTION_SLOTS) {
                pthread_mutex_unlock(&xl_function_lock);
                xl_unsupported("xlate: more host functions than the guest may look up with dlsym");
            }
            slot = xl_function_used + 1;
            xl_function_slots[slot - 1] = (struct xl_function_slot){found, xl_host_functions[entry].name, xl_host_functions[entry].shape};
            __atomic_store_n(&xl_function_used, slot, __ATOMIC_RELEASE);
        }
        pthread_mutex_unlock(&xl_function_lock);
        return &xl_function_region[slot - 1];
    }
    if (xl_host_code_address(found)) {
        int fd = xl_log_open("xl-dlsym.log");
        if (fd >= 0) {
            dprintf(fd, "dlsym refused the host function %s: guest code cannot call it\n", symbol);
            close(fd);
        }
        return NULL;
    }
    return found;
}

static void xl_function_entry(State *state)
{
    struct xl_function_slot *slot = xl_function_slot_at(XL_REG(state, PC));
    const char *shape = slot->shape;
    char result = *shape++;
    if (*shape == ':')
        shape++;
    uintptr_t words[4] = {0, 0, 0, 0};
    unsigned count = 0;
    for (; *shape && count < 4; shape++, count++) {
        uint64_t value = *(uint64_t *)((char *)state + XL_OFFSET_X0 + (XL_OFFSET_X1 - XL_OFFSET_X0) * count);
        switch (*shape) {
        case 'o': words[count] = xl_object_in(value, slot->name, count); break;
        case 'p': words[count] = xl_narrow_pointer(value, slot->name, count); break;
        case 'u': words[count] = (uintptr_t)xl_narrow_unsigned(value, UINT32_MAX, UINT64_MAX, slot->name, count); break;
        default: words[count] = (uintptr_t)xl_narrow_signed((int64_t)value, INT32_MIN, INT32_MAX, INT64_MIN, INT64_MAX, slot->name, count); break;
        }
    }
    uintptr_t returned = ((uintptr_t (*)(uintptr_t, uintptr_t, uintptr_t, uintptr_t))slot->host)(words[0], words[1], words[2], words[3]);
    uint64_t widened = returned;
    switch (result) {
    case 'o': widened = xl_object_out(returned); break;
    case 'p': widened = xl_widen_pointer(returned); break;
    case 'l': widened = (uint64_t)(int64_t)(int32_t)returned; break;
    default: break;
    }
    XL_REG(state, X0) = widened;
    xl_return(state);
}

void (*xl_imp_lookup(uint64_t address))(State *)
{
    if (xl_function_slot_at(address))
        return xl_function_entry;
    return xl_imp_slot_at(address) ? xl_imp_entry : NULL;
}

void xl_manual_class_getMethodImplementation(void *pack)
{
    struct __attribute__((packed)) { uint64_t cls, sel, r; } *p = pack;
    Class cls = xl_class_in(xl_narrow_pointer(p->cls, "class_getMethodImplementation", 0));
    SEL selector = (SEL)xl_narrow_pointer(p->sel, "class_getMethodImplementation", 1);
    p->r = xl_imp_out(class_getMethodImplementation(cls, selector), cls, selector, class_getInstanceMethod(cls, selector));
}

void xl_manual_method_getImplementation(void *pack)
{
    struct __attribute__((packed)) { uint64_t method, r; } *p = pack;
    Method method = (Method)xl_narrow_pointer(p->method, "method_getImplementation", 0);
    p->r = xl_imp_out(method_getImplementation(method), Nil, method_getName(method), method);
}

void xl_manual_method_setImplementation(void *pack)
{
    struct __attribute__((packed)) { uint64_t method, imp, r; } *p = pack;
    Method method = (Method)xl_narrow_pointer(p->method, "method_setImplementation", 0);
    SEL selector = method_getName(method);
    IMP imp = xl_imp_in(p->imp, selector, method_getTypeEncoding(method));
    p->r = xl_imp_out(method_setImplementation(method, imp), Nil, selector, method);
}

void xl_manual_class_addMethod(void *pack)
{
    struct __attribute__((packed)) { uint64_t cls, sel, imp, types, r; } *p = pack;
    SEL selector = (SEL)xl_narrow_pointer(p->sel, "class_addMethod", 1);
    const char *types = (const char *)xl_narrow_pointer(p->types, "class_addMethod", 3);
    IMP imp = xl_imp_in(p->imp, selector, types);
    p->r = class_addMethod(xl_class_in(xl_narrow_pointer(p->cls, "class_addMethod", 0)), selector, imp, types);
}

void xl_manual_class_replaceMethod(void *pack)
{
    struct __attribute__((packed)) { uint64_t cls, sel, imp, types, r; } *p = pack;
    Class cls = xl_class_in(xl_narrow_pointer(p->cls, "class_replaceMethod", 0));
    SEL selector = (SEL)xl_narrow_pointer(p->sel, "class_replaceMethod", 1);
    const char *types = (const char *)xl_narrow_pointer(p->types, "class_replaceMethod", 3);
    IMP replaced = class_replaceMethod(cls, selector, xl_imp_in(p->imp, selector, types), types);
    p->r = xl_imp_out(replaced, cls, selector, class_getInstanceMethod(cls, selector));
}

void xl_manual_imp_implementationWithBlock(void *pack)
{
    struct __attribute__((packed)) { uint64_t block, r; } *p = pack;
    p->r = xl_imp_out(imp_implementationWithBlock((id)xl_object_in(p->block, "imp_implementationWithBlock", 0)), Nil, NULL, NULL);
}

void xl_manual_imp_getBlock(void *pack)
{
    struct __attribute__((packed)) { uint64_t imp, r; } *p = pack;
    IMP imp = xl_imp_host(p->imp);
    p->r = imp ? xl_object_out((uintptr_t)imp_getBlock(imp)) : 0;
}

void xl_manual_imp_removeBlock(void *pack)
{
    struct __attribute__((packed)) { uint64_t imp, r; } *p = pack;
    IMP imp = xl_imp_host(p->imp);
    p->r = imp ? imp_removeBlock(imp) : 0;
}

void xl_manual_class_copyMethodList(void *pack)
{
    struct __attribute__((packed)) { uint64_t cls, count, r; } *p = pack;
    unsigned count = 0;
    Method *methods = class_copyMethodList(xl_class_in(xl_narrow_pointer(p->cls, "class_copyMethodList", 0)), &count);
    p->r = methods ? xl_widen_pointer_array((const void *const *)methods, count) : 0;
    free(methods);
    if (p->count)
        *(unsigned *)xl_narrow_pointer(p->count, "class_copyMethodList", 1) = count;
}

void xl_manual_objc_retain(struct xl_arc_pack *p)
{
    if (p->a0 && xl_is_guest_block(p->a0))
        p->r = xl_block_retain(p->a0);
    else
        p->r = xl_host_retain(p->a0, "objc_retain");
}

void xl_manual_objc_release(struct xl_arc_pack *p)
{
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

void xl_manual__objc_rootAutorelease(struct xl_arc_pack *p)
{
    if (p->a0 && !xl_is_guest_block(p->a0)) {
        uintptr_t guest = xl_narrow_pointer(p->a0, "_objc_rootAutorelease", 0);
        if (xl_proxy_in(guest) || xl_proxy_hold(guest)) {
            xl_proxy_guest_release(guest);
            p->r = p->a0;
            return;
        }
    }
    p->r = xl_object_out((uintptr_t)_objc_rootAutorelease((id)xl_object_in(p->a0, "_objc_rootAutorelease", 0)));
}

extern const struct xl_class_layout xl_class_layouts[];

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
    if (shift < 0)
        shift = 0;
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
