#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#include <math.h>
#include <stdio.h>

#include "spring-cases.h"

void host_attach_prefixed(const char *prefix);

static double call_double(id object, NSString *selector)
{
    return ((double (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(selector));
}

static CGFloat call_scalar(id object, NSString *selector)
{
    return ((CGFloat (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(selector));
}

static NSString *number(double value)
{
    if (isnan(value))
        return @"not a number";
    if (isinf(value))
        return value > 0 ? @"forever" : @"-forever";
    if (value >= (double)MAXFLOAT)
        return @"never";
    return [NSString stringWithFormat:@"%.9f", value];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: %s expectations.json\n", argv[0]);
            return 2;
        }
        host_attach_prefixed("");

        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        int failures = 0, checks = 0;
        for (unsigned index = 0; index < spring_case_count; index++) {
            struct spring_case example = spring_cases[index];
            CASpringAnimation *spring = [CASpringAnimation animation];
            spring.mass = example.mass;
            spring.stiffness = example.stiffness;
            spring.damping = example.damping;
            ((void (*)(id, SEL, CGFloat))objc_msgSend)(spring, NSSelectorFromString(@"charonHost_setInitialVelocity:"), example.velocity);

            NSString *name = @(example.name);
            checks++;
            if (spring.mass != example.mass || spring.stiffness != example.stiffness
                || spring.damping != example.damping || (double)spring.initialVelocity != example.velocity) {
                failures++;
                printf("FAIL %s: the host does not keep the values it was given (%g %g %g %g)\n", example.name,
                       (double)spring.mass, (double)spring.stiffness, (double)spring.damping, (double)spring.initialVelocity);
                continue;
            }

            checks++;
            CGFloat theirVelocity = spring.initialVelocity, ourVelocity = call_scalar(spring, @"charonHost_initialVelocity");
            if (theirVelocity != ourVelocity) {
                failures++;
                printf("FAIL %s velocity: the system answers %g, the backport answers %g\n", example.name, (double)theirVelocity, (double)ourVelocity);
            }

            checks++;
            double theirs = spring.settlingDuration, ours = call_double(spring, @"charonHost_settlingDuration");
            NSString *both = number(theirs);
            if (![both isEqual:number(ours)]) {
                failures++;
                printf("FAIL %s settling: the system answers %s, the backport answers %s\n", example.name,
                       number(theirs).UTF8String, number(ours).UTF8String);
                continue;
            }
            printf("ok   %s: velocity %g, settles in %s\n", example.name, (double)theirVelocity, both.UTF8String);
            records[name] = both;
        }

        CASpringAnimation *alias = [CASpringAnimation animation];
        ((void (*)(id, SEL, CGFloat))objc_msgSend)(alias, NSSelectorFromString(@"charonHost_setInitialVelocity:"), (CGFloat)7.5);
        checks++;
        if (alias.initialVelocity != (CGFloat)7.5) {
            failures++;
            printf("FAIL the backport's setter does not reach the property the system reads\n");
        }
        alias.initialVelocity = -2.25;
        checks++;
        if (call_scalar(alias, @"charonHost_initialVelocity") != (CGFloat)-2.25) {
            failures++;
            printf("FAIL the backport's getter does not read the property the system writes\n");
        }

        if (failures == 0) {
            NSData *json = [NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingSortedKeys error:NULL];
            [json writeToFile:@(argv[1]) atomically:YES];
        }
        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
