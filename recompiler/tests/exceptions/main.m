#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

extern void xl_guarded(int mode);
extern int xl_catch_all(int mode);
extern int xl_destroyed(void);
extern int xl_unwound(void);

@interface XLError : NSException
@end

@implementation XLError
@end

static int finals;
static int rethrown;

__attribute__((noinline)) static void raise_in_guest(NSString *name)
{
    @throw [NSException exceptionWithName:name reason:@"raised by the guest" userInfo:nil];
}

__attribute__((noinline)) static void raise_in_host(void)
{
    NSArray *array = [NSArray arrayWithObject:@1];
    (void)[array objectAtIndex:5];
}

__attribute__((noinline)) void xl_level3(int mode)
{
    switch (mode) {
        case 0:
            raise_in_guest(@"GuestError");
            break;
        case 1:
            raise_in_host();
            break;
        case 2:
            @throw [[[XLError alloc] initWithName:@"XLError" reason:@"raised by the guest" userInfo:nil] autorelease];
        case 3:
            @throw @"a string";
        default:
            break;
    }
}

__attribute__((noinline)) static NSString *classify(int mode)
{
    @try {
        xl_guarded(mode);
        return @"nothing thrown";
    } @catch (XLError *error) {
        return [NSString stringWithFormat:@"XLError %@", [error name]];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"NSException %@", [exception name]];
    } @catch (id object) {
        return [object isKindOfClass:[NSString class]] ? @"id string" : @"id other";
    } @finally {
        ++finals;
    }
}

__attribute__((noinline)) static void rethrower(int mode)
{
    @try {
        xl_guarded(mode);
    } @catch (NSException *exception) {
        ++rethrown;
        @throw;
    }
}

__attribute__((noinline)) static NSString *rethrown_name(int mode)
{
    @try {
        rethrower(mode);
        return @"nothing thrown";
    } @catch (NSException *exception) {
        return [exception name];
    }
}

__attribute__((noinline)) static long registers(int rounds)
{
    long a = 3, b = 5, c = 7, d = 11;
    int caught = 0;
    for (int i = 0; i < rounds; i++) {
        @try {
            xl_guarded(i & 1);
            a += 100;
        } @catch (NSException *exception) {
            caught++;
            b += 2;
        }
        c ^= i;
        d += caught;
    }
    return a * 1000003 + b * 10007 + c * 101 + d + caught;
}

__attribute__((noinline)) static long two_regions(int rounds)
{
    long total = 0;
    for (int i = 0; i < rounds; i++) {
        @try {
            xl_guarded(0);
            total += 1;
        } @catch (NSException *exception) {
            total += 2;
        }
        @try {
            xl_guarded(1);
            total += 3;
        } @catch (NSException *exception) {
            total += 5;
        }
    }
    return total;
}

__attribute__((noinline)) static NSString *through_block(void)
{
    @try {
        [[NSArray arrayWithObjects:@1, @2, @3, nil] enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
            if (index == 1) {
                raise_in_guest(@"InBlock");
            }
        }];
        return @"nothing thrown";
    } @catch (NSException *exception) {
        return [exception name];
    }
}

__attribute__((noinline)) static int tail_target(int value)
{
    return value * 2 + 1;
}

__attribute__((noinline)) static int tail_after_catch(int mode)
{
    @try {
        xl_guarded(mode);
    } @catch (NSException *exception) {
        ++finals;
    }
    return tail_target(mode);
}

static char thread_result[64];

static void *thread_body(void *unused)
{
    @autoreleasepool {
        @try {
            xl_guarded(1);
        } @catch (NSException *exception) {
            snprintf(thread_result, sizeof thread_result, "%s", [[exception name] UTF8String]);
        }
    }
    return NULL;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        const char *labels[] = {"guest throw", "host throw", "guest subclass", "guest object"};
        for (int mode = 0; mode < 4; mode++) {
            printf("%s: %s\n", labels[mode], [classify(mode) UTF8String]);
        }
        printf("no throw: %s\n", [classify(4) UTF8String]);
        printf("finally blocks: %d\n", finals);
        printf("destructors run: %d\n", xl_destroyed());
        printf("rethrow of a guest throw: %s\n", [rethrown_name(0) UTF8String]);
        printf("rethrow of a host throw: %s\n", [rethrown_name(1) UTF8String]);
        printf("rethrow count: %d\n", rethrown);
        printf("catch all of a guest throw: %d\n", xl_catch_all(0));
        printf("catch all of a host throw: %d\n", xl_catch_all(1));
        printf("catch all of no throw: %d\n", xl_catch_all(4));
        printf("catch all count: %d\n", xl_unwound());
        int rounds = argc > 1 ? atoi(argv[1]) : 2000;
        printf("registers after %d catches: %ld\n", rounds, registers(rounds));
        printf("two regions in %d rounds: %ld\n", rounds, two_regions(rounds));
        printf("through a host frame: %s\n", [through_block() UTF8String]);
        printf("tail call after a catch: %d %d\n", tail_after_catch(0), tail_after_catch(4));
        pthread_t thread;
        pthread_create(&thread, NULL, thread_body, NULL);
        pthread_join(thread, NULL);
        printf("on a second thread: %s\n", thread_result);
        printf("destructors run at the end: %d\n", xl_destroyed());
    }
    return 0;
}
