#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "vtclass-cases.h"
#ifdef REVENANT_HOST_DIFFERENTIAL
#    import "RevenantVideoToolbox.h"
#endif
#include "roundtrip-cases.h"

static long long ReadBack(id object, const char *property)
{
    SEL selector = NSSelectorFromString([NSString stringWithUTF8String:property]);
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature)
        return LLONG_MIN;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    invocation.target = object;
    [invocation invoke];
    NSUInteger size = signature.methodReturnLength;
    if (size == sizeof(float)) {
        float value = 0.0f;
        [invocation getReturnValue:&value];
        return (long long)value;
    }
    if (size < sizeof(long long)) {
        unsigned char value = 0;
        [invocation getReturnValue:&value];
        return (long long)value;
    }
    long long value = 0;
    [invocation getReturnValue:&value];
    return value;
}

void vtclass_roundtrip(CertificateRecorder record)
{
    for (unsigned i = 0; i < VT_ROUND_TRIP_CASES; i++) {
        const VTRoundTripCase *entry = &vtRoundTripCases[i];
        NSString *declared = @(entry->className);
        SEL selector = NSSelectorFromString(@(entry->selector));
        NSString *tag = [NSString stringWithFormat:@"roundtrip.%@", declared];

        NSString *methodTag = [NSString stringWithFormat:@"method.%@.%@", declared, @(entry->selector)];
        record([methodTag stringByAppendingString:@".selector"], NSStringFromSelector(selector));
#ifdef REVENANT_HOST_DIFFERENTIAL
        NSString *lookup = [@"Revenant" stringByAppendingString:declared];
        Class port = NSClassFromString(lookup);
        record([methodTag stringByAppendingString:@".isInstance"],
               [port instancesRespondToSelector:selector] ? @"1" : @"0");
        record([methodTag stringByAppendingString:@".isClass"],
               class_getClassMethod(port, selector) ? @"1" : @"0");

        id made = nil;
        NSString *raised = nil;
        @try {
            made = port ? entry->construct(port, selector) : nil;
        } @catch (NSException *exception) {
            raised = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
            fprintf(stderr, "vtclass: %s %s raised %s: %s\n", entry->className, entry->selector,
                    [exception.name UTF8String], [exception.reason UTF8String]);
        }
        record([tag stringByAppendingString:@".exists"], made ? @"1" : @"0");
        if (raised)
            record([tag stringByAppendingString:@".raised"], raised);
        unsigned mismatches = entry->expectedCount;
        if (made) {
            mismatches = 0;
            for (unsigned p = 0; p < entry->expectedCount; p++) {
                long long got = ReadBack(made, entry->expected[p].property);
                record([NSString stringWithFormat:@"%@.%s", tag, entry->expected[p].property],
                       [NSString stringWithFormat:@"%lld", got]);
                if (got != entry->expected[p].value)
                    mismatches++;
            }
        }


        Class kvcClass = NSClassFromString(@"RevenantVTTemporalNoiseFilterConfiguration");
        if (!kvcClass)
            kvcClass = NSClassFromString(@"VTTemporalNoiseFilterConfiguration");
        OSType planted = (OSType)0x34323676;
        NSString *kvcTag = @"kvc.VTTemporalNoiseFilterConfiguration.sourcePixelFormat";
        id kvcTarget = nil;
        if ([kvcClass isSubclassOfClass:NSClassFromString(@"RevenantVTTemporalNoiseFilterConfiguration")]) {
            kvcTarget = entry->construct(kvcClass, NSSelectorFromString(
                @"initWithFrameWidth:frameHeight:sourcePixelFormat:"));
        } else {
            kvcTarget = class_createInstance(kvcClass, 0);
        }
        if (!kvcTarget) {
            record(kvcTag, @"no-object");
        } else {
            @try {
                [kvcTarget setValue:@(planted) forKey:@"sourcePixelFormat"];
                id read = [kvcTarget valueForKey:@"sourcePixelFormat"];
                record(kvcTag, [NSString stringWithFormat:@"%lu", (unsigned long)[read unsignedIntValue]]);
            } @catch (NSException *exception) {
                record(kvcTag, [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
                fprintf(stderr, "vtclass: kvc raised %s: %s\n", [exception.name UTF8String],
                        [exception.reason UTF8String]);
            }
        }        record([tag stringByAppendingString:@".mismatches"], [NSString stringWithFormat:@"%u", mismatches]);
#else
        Class host = NSClassFromString(declared);
        record([methodTag stringByAppendingString:@".isInstance"],
               [host instancesRespondToSelector:selector] ? @"1" : @"0");
        record([methodTag stringByAppendingString:@".isClass"],
               class_getClassMethod(host, selector) ? @"1" : @"0");

        Class kvcHost = NSClassFromString(@"VTTemporalNoiseFilterConfiguration");
        NSString *kvcTag = @"kvc.VTTemporalNoiseFilterConfiguration.sourcePixelFormat";
        id kvcTarget = class_createInstance(kvcHost, 0);
        if (!kvcTarget) {
            record(kvcTag, @"no-object");
        } else {
            @try {
                [kvcTarget setValue:@((OSType)0x34323676) forKey:@"sourcePixelFormat"];
                id read = [kvcTarget valueForKey:@"sourcePixelFormat"];
                record(kvcTag, [NSString stringWithFormat:@"%lu", (unsigned long)[read unsignedIntValue]]);
            } @catch (NSException *exception) {
                record(kvcTag, [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
            }
        }
#endif
    }
}
