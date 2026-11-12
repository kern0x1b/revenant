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
        grow(target << 10);
        measure("host");
        regions("host", 0x1000, 0xfffff000);

        xl_load_status reserved = xl_reserve(path);
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
        regions("end", 0x1000, 0xfffff000);
        line(@"done");
    }
    return 0;
}
