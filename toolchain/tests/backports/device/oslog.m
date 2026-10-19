#import <Foundation/Foundation.h>
#import <os/log.h>
#include <asl.h>
#include <dlfcn.h>
#include <errno.h>
#include <unistd.h>
#import "check.h"
#include "../host/oslog/battery.h"
#include "oslog-expectations.h"

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSDictionary *messages_from_asl(NSTimeInterval seconds, NSUInteger wanted)
{
    NSMutableDictionary *found = [NSMutableDictionary dictionary];
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    do {
        aslmsg query = asl_new(ASL_TYPE_QUERY);
        char pid[16];
        snprintf(pid, sizeof pid, "%d", getpid());
        asl_set_query(query, ASL_KEY_PID, pid, ASL_QUERY_OP_EQUAL);
        aslresponse response = asl_search(NULL, query);
        aslmsg message;
        while ((message = aslresponse_next(response))) {
            const char *text = asl_get(message, ASL_KEY_MSG);
            const char *facility = asl_get(message, ASL_KEY_FACILITY);
            const char *level = asl_get(message, ASL_KEY_LEVEL);
            if (text)
                found[@(text)] = @{@"facility": facility ? @(facility) : @"", @"level": level ? @(level) : @""};
        }
        aslresponse_free(response);
        asl_free(query);
        if (found.count >= wanted)
            break;
        usleep(200000);
    } while ([limit timeIntervalSinceNow] > 0);
    return found;
}

int main(void)
{
    @autoreleasepool {
        setenv("TZ", "UTC", 1);
        tzset();
        CHECK_EQUAL(image_of((const void *)&_os_log_internal), @"libFoundationBackports.dylib", "_os_log_internal comes from the backports library");
        CHECK_EQUAL(image_of((const void *)&_os_log_create), @"libFoundationBackports.dylib", "and _os_log_create");
        CHECK_EQUAL(image_of((const void *)&_os_log_default), @"libFoundationBackports.dylib", "and _os_log_default");
        CHECK_EQUAL(image_of((const void *)&os_log_type_enabled), @"libFoundationBackports.dylib", "and os_log_type_enabled");

        os_log_t log = os_log_create("space.kern0x1b.probe", "one");
        os_log_t same = os_log_create("space.kern0x1b.probe", "one");
        os_log_t other = os_log_create("space.kern0x1b.probe", "two");
        CHECK(log && log == same && log != other && OS_LOG_DEFAULT != log, "the same subsystem and category are the same log, another category another log");
        CFTypeRef held = (__bridge CFTypeRef)log;
        for (int round = 0; round < 100000; round++) {
            CFRetain(held);
            CFRelease(held);
        }
        CHECK((NSUInteger)CFGetRetainCount(held) > 1000000 && (NSUInteger)CFGetRetainCount((__bridge CFTypeRef)OS_LOG_DEFAULT) > 1000000,
              "a log is never let go, and keeping it and dropping it any number of times does no harm, the default log included");

        CHECK(os_log_type_enabled(log, OS_LOG_TYPE_DEFAULT) && os_log_type_enabled(log, OS_LOG_TYPE_ERROR) && os_log_type_enabled(log, OS_LOG_TYPE_FAULT)
              && os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT),
              "default, error and fault messages are enabled");
        CHECK(!os_log_type_enabled(log, OS_LOG_TYPE_INFO) && !os_log_type_enabled(log, OS_LOG_TYPE_DEBUG), "info and debug are not, as the release has them with no preferences");
        CHECK(!os_log_type_enabled(NULL, OS_LOG_TYPE_DEFAULT) && os_log_is_enabled(log) && !os_log_is_debug_enabled(log),
              "no log at all is never enabled, and the two older questions answer as the release does");

        int index = 0;
        const char *s = "dyn", *nul = NULL;
        NSString *o = @"obj";
        id nilo = nil;
        int i = -7;
        unsigned u = 4000000000u;
        short sh = -5;
        signed char ch = -3;
        long long ll = 1234567890123LL;
        double d = 3.14159265;
        float f = 2.5f;
        void *p = (void *)0x1234;
        size_t z = 99;
        char c = 'q';
        unsigned char uu[16] = {0xde, 0xad, 0xbe, 0xef, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
#define CASE(format, ...) \
        do { \
            char category[16]; \
            snprintf(category, sizeof category, "c%d", ++index); \
            os_log_t named = os_log_create("probe", category); \
            errno = 0; \
            os_log(named, format, ##__VA_ARGS__); \
        } while (0);
        OSLOG_BATTERY(CASE)
        os_log_error(log, "an error %d", 1);
        os_log_fault(log, "a fault %d", 2);
        os_log_info(log, "info that is not written");
        os_log_debug(log, "debug that is not written");
        os_log(OS_LOG_DEFAULT, "a message of the default log");
        os_log(NULL, "a message of no log");

        NSUInteger expected = sizeof charon_oslog_expected / sizeof charon_oslog_expected[0];
        NSDictionary *found = messages_from_asl(15, expected + 3);
        NSUInteger matching = 0;
        for (NSUInteger row = 0; row < expected; row++) {
            NSString *want = [NSString stringWithFormat:@"[c%d] %@", charon_oslog_expected[row].index, @(charon_oslog_expected[row].text)];
            NSString *got = nil;
            for (NSString *text in found)
                if ([text isEqual:want])
                    got = text;
            CHECK_EQUAL(got, want, ([[NSString stringWithFormat:@"case %d is written as the release's own formatter writes it", charon_oslog_expected[row].index] UTF8String]));
            matching += got != nil;
        }
        CHECK(matching == expected, "every case of the battery arrived in the system log");
        NSDictionary *error = found[@"[one] an error 1"], *fault = found[@"[one] a fault 2"], *plain = found[@"a message of the default log"];
        CHECK([error[@"facility"] isEqual:@"space.kern0x1b.probe"] && [error[@"level"] isEqual:@"3"], "an error is written at ASL's error level under the subsystem as facility");
        CHECK([fault[@"level"] isEqual:@"2"], "a fault at the critical level");
        CHECK(plain != nil && [plain[@"level"] isEqual:@"5"], "the default log writes at the notice level with no category in front");
        CHECK(found[@"[one] info that is not written"] == nil && found[@"[one] debug that is not written"] == nil && found[@"a message of no log"] == nil,
              "what is not enabled is not written, and no log writes nothing");

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
