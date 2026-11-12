#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "xl_loader.h"

@protocol RCFToken <NSObject>
- (NSInteger)value;
@end

@protocol RCFClient <NSObject>
- (NSInteger)bump;
- (NSInteger)seed;
- (NSInteger)describedLength;
- (NSObject *)hostBundle;
- (id<RCFToken>)tokenForAction:(NSInteger)action;
- (void)executeWithAction:(NSInteger)action completion:(void (^)(id<RCFToken> token, NSError *error))completion;
@end

static void line(NSString *text)
{
    printf("%s\n", text.UTF8String);
    fflush(stdout);
}

static void report(const char *name, BOOL passed)
{
    printf("%s %s\n", passed ? "ok" : "FAIL", name);
    fflush(stdout);
}

static void measure(const char *tag)
{
    struct task_basic_info info;
    mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count);
    thread_act_array_t threads;
    mach_msg_type_number_t thread_count = 0;
    task_threads(mach_task_self(), &threads, &thread_count);
    for (mach_msg_type_number_t i = 0; i < thread_count; i++)
        mach_port_deallocate(mach_task_self(), threads[i]);
    vm_deallocate(mach_task_self(), (vm_address_t)threads, thread_count * sizeof *threads);
    printf("measure %s resident=%luK virtual=%luK threads=%u\n", tag, (unsigned long)info.resident_size / 1024,
           (unsigned long)info.virtual_size / 1024, thread_count);
    fflush(stdout);
}

static void regions(const char *tag, unsigned long low, unsigned long high)
{
    vm_address_t address = 0;
    natural_t depth = 0;
    for (;;) {
        vm_size_t size = 0;
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        if (vm_region_recurse_64(mach_task_self(), &address, &size, &depth, (vm_region_recurse_info_t)&info, &count) != KERN_SUCCESS)
            break;
        if (info.is_submap) {
            depth++;
            continue;
        }
        if (address < high && address + size > low)
            printf("map %s %08lx-%08lx %c%c%c\n", tag, (unsigned long)address, (unsigned long)(address + size),
                   info.protection & VM_PROT_READ ? 'r' : '-', info.protection & VM_PROT_WRITE ? 'w' : '-',
                   info.protection & VM_PROT_EXECUTE ? 'x' : '-');
        address += size;
    }
    fflush(stdout);
}

static void occupy(const char *range)
{
    unsigned long low = 0, high = 0;
    BOOL parsed = sscanf(range + 1, "%lx-%lx", &low, &high) == 2 && low < high;
    vm_address_t address = low;
    BOOL held = parsed && vm_allocate(mach_task_self(), &address, high - low, VM_FLAGS_FIXED) == KERN_SUCCESS;
    if (held)
        vm_protect(mach_task_self(), low, high - low, FALSE, VM_PROT_NONE);
    report("occupy", held);
}

#ifdef RC_SWIFT_HOST
// The host's Swift runtime (the libswiftCore this executable is linked with) and the host's own Swift code, hostswift.swift.
// The library brings a Swift runtime of its own; what the host's Swift sees by name must stay the host's.
extern void *rch_make_box(NSInteger seed);
extern void *rch_make_array(NSInteger seed);
extern void *rch_make_string(NSInteger seed);

static NSMutableDictionary *hostClasses;     // class name -> the host's class, for every class of the host's libswiftCore
static NSString *hostRuntime;                // the image of the host's libswiftCore
static Class bridgedClasses[3];

static void snapshotHostRuntime(void)
{
    Class value = objc_getClass("__SwiftValue");
    const char *image = value ? class_getImageName(value) : NULL;
    hostRuntime = image ? [NSString stringWithUTF8String:image] : nil;
    hostClasses = [NSMutableDictionary dictionary];
    unsigned count = 0;
    const char **names = hostRuntime ? objc_copyClassNamesForImage(hostRuntime.UTF8String, &count) : NULL;
    for (unsigned i = 0; i < count; i++)
        hostClasses[[NSString stringWithUTF8String:names[i]]] = [NSValue valueWithPointer:(__bridge const void *)objc_getClass(names[i])];
    free(names);
    printf("host runtime %s: %lu classes\n", image ? image : "?", (unsigned long)hostClasses.count);
    fflush(stdout);
}

// Every name of the host's runtime still answers with the host's class
static BOOL hostNamesUnchanged(void)
{
    if (!hostClasses.count)
        return NO;
    BOOL same = YES;
    for (NSString *name in hostClasses) {
        Class now = objc_getClass(name.UTF8String);
        if ((__bridge const void *)now != [hostClasses[name] pointerValue]) {
            printf("changed %s\n", name.UTF8String);
            same = NO;
        }
    }
    fflush(stdout);
    return same;
}

// The library registers no class under a name of the host's runtime
static BOOL namesDisjoint(const char *library)
{
    // the image is named by the path dyld resolved, which need not be the path that was given
    const char *base = strrchr(library, '/') ? strrchr(library, '/') + 1 : library;
    unsigned images = 0, count = 0;
    const char **list = objc_copyImageNames(&images);
    const char *image = library;
    for (unsigned i = 0; i < images; i++) {
        const char *name = strrchr(list[i], '/') ? strrchr(list[i], '/') + 1 : list[i];
        if (strcmp(name, base) == 0)
            image = list[i];
    }
    const char **names = objc_copyClassNamesForImage(image, &count);
    free(list);
    BOOL disjoint = count > 0;
    for (unsigned i = 0; i < count; i++) {
        if (hostClasses[[NSString stringWithUTF8String:names[i]]]) {
            printf("both %s\n", names[i]);
            disjoint = NO;
        }
    }
    printf("library registers %u classes\n", count);
    fflush(stdout);
    free(names);
    return disjoint;
}

// What the host's Swift boxes and bridges: the same classes, with the same contents, every time
static BOOL hostBridges(BOOL record)
{
    id objects[3] = {(__bridge_transfer id)rch_make_box(7), (__bridge_transfer id)rch_make_array(7), (__bridge_transfer id)rch_make_string(7)};
    BOOL ok = YES;
    for (int i = 0; i < 3; i++) {
        Class cls = object_getClass(objects[i]);
        if (record)
            bridgedClasses[i] = cls;
        BOOL named = strncmp(class_getName(cls), "XLG.", 4) != 0 && cls == bridgedClasses[i];
        if (!named)
            printf("bridged object %d is a %s\n", i, class_getName(cls));
        ok = ok && named;
    }
#ifdef RC_BRIDGING
    NSArray *array = objects[1];
    NSString *string = objects[2];
    BOOL array_ok = [array isKindOfClass:[NSArray class]] && array.count == 3 && [array[1] isEqual:@"item-7"] && array[0] && array[2];
    BOOL string_ok = [string isKindOfClass:[NSString class]] && string.length == 12 && [string hasPrefix:@"host-7-h"];
#else
    id array = objects[1], string = objects[2];
    BOOL array_ok = YES, string_ok = YES;   // no Foundation overlay: Swift boxes them, and the classes above are what is checked
#endif
    if (!array_ok || !string_ok)
        printf("bridged contents: array %s %s (%lu items), string %s (%lu)\n", class_getName(object_getClass(array)), array_ok ? "ok" : "wrong",
               (unsigned long)([array respondsToSelector:@selector(count)] ? [array count] : 0), class_getName(object_getClass(string)),
               (unsigned long)([string respondsToSelector:@selector(length)] ? [string length] : 0));
    ok = ok && array_ok && string_ok;
    fflush(stdout);
    return ok;
}
#endif

static void grow(size_t target_kilobytes)
{
    struct task_basic_info info;
    mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count);
    while (info.resident_size / 1024 < target_kilobytes) {
        size_t chunk = 1 << 20;
        volatile char *block = malloc(chunk);
        for (size_t i = 0; i < chunk; i += 4096)
            block[i] = 1;
        task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count);
    }
}

int main(int argc, char **argv)
{
    alarm(180);
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: host LIBRARY [RESIDENT-MB [@LOW-HIGH | PRELOADED-DYLIB]...]\n");
            return 2;
        }
        const char *path = argv[1];
        size_t target = argc > 2 ? (size_t)atoi(argv[2]) : 85;
        for (int index = 3; index < argc; index++) {
            if (argv[index][0] == '@') {
                occupy(argv[index]);
                continue;
            }
            void *image = dlopen(argv[index], RTLD_NOW | RTLD_GLOBAL);
            report("preload", image != NULL);
            if (!image)
                line([NSString stringWithFormat:@"error %s", dlerror()]);
        }
        // An app reserves the range before its heap grows (a constructor), and loads the library when it first needs it
        xl_load_status reserved = xl_reserve(path);
        grow(target << 10);
        measure("host");
        regions("host", 0x1000, 0xfffff000);
#ifdef RC_SWIFT_HOST
        snapshotHostRuntime();
        report("host.bridge.before", hostBridges(YES));
#endif

        report("reserve", reserved == XL_LOAD_OK);
        if (reserved != XL_LOAD_OK)
            line([NSString stringWithFormat:@"error %s", xl_load_error()]);
        measure("reserved");

        xl_load_status loaded = xl_load(path);
        report("load", loaded == XL_LOAD_OK);
        if (loaded != XL_LOAD_OK) {
            line([NSString stringWithFormat:@"error %s", xl_load_error()]);
            return 1;
        }
        measure("loaded");
        regions("loaded", 0x1000, 0xfffff000);
#ifdef RC_SWIFT_HOST
        report("host.names", hostNamesUnchanged());
        report("names.disjoint", namesDisjoint(path));
#endif

        Class cls = NSClassFromString(@"RCFClient");
        report("class", cls != Nil);
        id<RCFClient> client = ((id (*)(id, SEL, NSInteger))objc_msgSend)(cls, @selector(clientWithSeed:), 7);
        report("create", client != nil);
        report("methods", [client bump] == 1 && [client bump] == 2);
        report("describe", [client seed] == 7 && [client describedLength] == 10);
        report("bundle", [client hostBundle] == [NSBundle mainBundle]);
        report("bundle.path", [[[client hostBundle] performSelector:@selector(bundlePath)] isEqualToString:[[NSBundle mainBundle] bundlePath]]);
        id<RCFToken> token = [client tokenForAction:5];
        report("token", [token value] == 7051);
        measure("called");

        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block NSInteger async = 0;
        __block BOOL main_thread = YES;
        [client executeWithAction:9 completion:^(id<RCFToken> result, NSError *error) {
            async = [result value];
            main_thread = [NSThread isMainThread];
            dispatch_semaphore_signal(done);
        }];
        BOOL arrived = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0;
        report("completion", arrived && async == 7091);
        report("completion.thread", arrived && !main_thread);
        measure("threaded");
#ifdef RC_SWIFT_HOST
        report("host.bridge.after", hostBridges(NO) && hostNamesUnchanged());
#endif
        regions("end", 0x1000, 0xfffff000);
        line(@"done");
    }
    return 0;
}
