#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <mach/mach.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

#include "xl_loader.h"

extern long rcsdk_host_swift(long seed);

static double started;

static double now(void)
{
    struct timeval t;
    gettimeofday(&t, NULL);
    return (double)t.tv_sec + (double)t.tv_usec / 1e6;
}

static void step(const char *name, NSString *detail)
{
    struct task_basic_info info;
    mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count);
    printf("[%7.2f s] %s resident=%luK %s\n", now() - started, name, (unsigned long)info.resident_size / 1024, detail ? detail.UTF8String : "");
    fflush(stdout);
}

static NSString *failure(id error)
{
    if (!error)
        return @"error=nil";
    return [NSString stringWithFormat:@"error=%@ %ld '%@'", [error domain], (long)[error code], [error localizedDescription]];
}

static Class find(const char *name)
{
    return (__bridge Class)xl_find_class(name);
}

static BOOL spin(volatile int *flag, int seconds)
{
    double deadline = now() + seconds;
    while (!*flag && now() < deadline)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
    return *flag != 0;
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: rcsdk LIBRARY [SITE-KEY|-] [--execute] [--seconds N] [--rounds N]\n");
        return 2;
    }
    int seconds = 60, rounds = 1;
    BOOL execute = NO;
    NSString *key = argc > 2 && strcmp(argv[2], "-") != 0 && strncmp(argv[2], "--", 2) != 0 ? @(argv[2]) : @"";
    for (int index = 2; index < argc; index++) {
        if (strcmp(argv[index], "--execute") == 0)
            execute = YES;
        else if (strcmp(argv[index], "--seconds") == 0 && index + 1 < argc)
            seconds = atoi(argv[++index]);
        else if (strcmp(argv[index], "--rounds") == 0 && index + 1 < argc)
            rounds = atoi(argv[++index]);
    }
    alarm((unsigned)(seconds * 2 * rounds) + 30);
    started = now();
    const char *path = argv[1];
    step("start", [NSString stringWithFormat:@"key length %lu execute=%d rounds=%d", (unsigned long)key.length, execute, rounds]);
    step("host swift", [NSString stringWithFormat:@"%ld", rcsdk_host_swift(7)]);
    xl_load_status reserved = xl_reserve(path);
    step("reserve", [NSString stringWithFormat:@"status=%d %s", reserved, reserved ? xl_load_error() : ""]);
    if (reserved != XL_LOAD_OK)
        return 1;
    xl_load_status loaded = xl_load(path);
    step("load", [NSString stringWithFormat:@"status=%d %s", loaded, loaded ? xl_load_error() : ""]);
    if (loaded != XL_LOAD_OK)
        return 1;
    Class recaptcha = find("RecaptchaEnterprise.Recaptcha");
    Class action = find("RecaptchaEnterprise.RecaptchaAction");
    SEL fetchSelector = sel_registerName("fetchClientWithSiteKey:completion:");
    SEL loginSelector = sel_registerName("login");
    SEL runSelector = sel_registerName("executeWithAction:completion:");
    BOOL haveFetch = recaptcha && class_respondsToSelector(object_getClass(recaptcha), fetchSelector);
    step("find", [NSString stringWithFormat:@"Recaptcha=%p RecaptchaAction=%p fetch=%d", (__bridge void *)recaptcha, (__bridge void *)action, haveFetch]);
    if (!haveFetch || !action)
        return 1;
    __block int failures = 0;
    for (int round = 1; round <= rounds; round++) {
        @autoreleasepool {
            id login = ((id (*)(Class, SEL))objc_msgSend)(action, loginSelector);
            step("action", [NSString stringWithFormat:@"round %d login=%p", round, (__bridge void *)login]);
            __block id client = nil;
            __block NSString *fetched = nil;
            __block volatile int fetchDone = 0;
            double begin = now();
            void (^completion)(id, id) = ^(id gotClient, id error) {
                client = gotClient;
                fetched = [NSString stringWithFormat:@"%.2f s client=%p %s %@", now() - begin, (__bridge void *)gotClient,
                           gotClient ? class_getName(object_getClass(gotClient)) : "nil", failure(error)];
                fetchDone = 1;
            };
            step("fetch", [NSString stringWithFormat:@"round %d", round]);
            ((void (*)(Class, SEL, id, id))objc_msgSend)(recaptcha, fetchSelector, key, completion);
            BOOL answered = spin(&fetchDone, seconds);
            step("fetched", answered ? fetched : @"NO ANSWER");
            if (!answered) {
                failures++;
                continue;
            }
            if (!execute || !client || !class_respondsToSelector(object_getClass(client), runSelector))
                continue;
            __block NSString *executed = nil;
            __block volatile int runDone = 0;
            double second = now();
            void (^done)(id, id) = ^(id token, id error) {
                executed = [NSString stringWithFormat:@"%.2f s token length %lu %@", now() - second, token ? (unsigned long)[token length] : 0UL, failure(error)];
                runDone = 1;
            };
            ((void (*)(id, SEL, id, id))objc_msgSend)(client, runSelector, login, done);
            answered = spin(&runDone, seconds);
            step("executed", answered ? executed : @"NO ANSWER");
            if (!answered)
                failures++;
        }
    }
    __block volatile int settled = 0;
    step("settle", @"3 s for the pools of the guest threads");
    spin(&settled, 3);
    step("done", [NSString stringWithFormat:@"failures=%d", failures]);
    return failures ? 1 : 0;
}
