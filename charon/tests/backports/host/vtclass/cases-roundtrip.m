#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "vtclass-cases.h"
#ifdef CHARON_HOST_DIFFERENTIAL
#    import "CharonVideoToolbox.h"
#endif
#include "roundtrip-cases.h"

// The port's own value round-trip, over every class the SDK gives a designated initialiser.
//
// TWO HALVES, GENERATED AND NOT. roundtrip-cases.h is emitted by emit.py: the class, the selector, a
// TYPED call that constructs the object, and the scalar properties with the value each must read back.
// What cannot be generated is a call, so the calling is here.
//
// WHY A TYPED CALL RATHER THAN NSInvocation: setArgument:atIndex: takes a pointer to the value in its
// own size, and the sizes here differ - BOOL is one byte, float four, NSInteger and every enumeration
// eight, CMTime a struct. A size guessed wrong corrupts the argument list silently, and a round-trip that
// reports a mismatch of its own making is worse than no round-trip at all. The generated call writes
// every cast and every argument in the type the SDK declares, so the compiler checks all seventeen.
//
// WHY IT IS PORT-ONLY, and the measurement behind that: the host's VideoToolbox refuses dimensions it
// does not support, and its own documentation says initWithFrameWidth: returns nil for them, so there is
// no object on that side to read a value out of. compare.py therefore never visits these records - it
// iterates the HOST's records - and THIS FILE CHECKS ITSELF. It knows what it put in, because the
// expectation is generated from the same argument list, so a value stored under the wrong key cannot
// report success: the mismatch count is the check.

// One property read back through its own accessor, by selector, so the value that comes out is the
// accessor's and not something this file reconstructed.
static long long ReadBack(id object, const char *property)
{
    SEL selector = NSSelectorFromString([NSString stringWithUTF8String:property]);
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature)
        return LLONG_MIN;                 // no accessor: the shape comparison asks about that
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    invocation.target = object;
    [invocation invoke];
    // AT THE RETURN'S OWN SIZE, which is the defect this read-back had: it took a long long for
    // everything, and the table holds a float (scaleFactor - four bytes) and a BOOL (usePrecomputedFlow -
    // one byte), so their upper bytes were whatever was on the stack. scaleFactor read back 1920 where it
    // was 2, and 1920 was the value of the FIRST NSInteger argument - which made it look exactly like an
    // argument stored under another's name, and it was not: the initialiser is
    // CharonValueSet(self, @(scaleFactor), @"scaleFactor"), and reading a float into a long long
    // concatenated the two. The signature knows the size, so the signature supplies it.
    NSUInteger size = signature.methodReturnLength;
    if (size == sizeof(float)) {
        float value = 0.0f;
        [invocation getReturnValue:&value];
        return (long long)value;
    }
    if (size < sizeof(long long)) {
        unsigned char value = 0;           // BOOL, and every other one-byte return
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

        // The SHAPE, asked of both builds, and the host has to agree: the initialiser exists, is spelled
        // the SDK spells, and is an instance method rather than a class method.
        NSString *methodTag = [NSString stringWithFormat:@"method.%@.%@", declared, @(entry->selector)];
        record([methodTag stringByAppendingString:@".selector"], NSStringFromSelector(selector));
#ifdef CHARON_HOST_DIFFERENTIAL
        // The port's class is the RENAMED one - rename.py has #defined its name in this build - and the
        // table carries the SDK's own spelling as a string, which a macro does not rewrite, so the prefix
        // is added here. It is the same transformation rename.py applies, written once here rather than
        // seventeen times, because the table's names are data and this is code.
        NSString *lookup = [@"Charon" stringByAppendingString:declared];
        Class port = NSClassFromString(lookup);
        record([methodTag stringByAppendingString:@".isInstance"],
               [port instancesRespondToSelector:selector] ? @"1" : @"0");
        record([methodTag stringByAppendingString:@".isClass"],
               class_getClassMethod(port, selector) ? @"1" : @"0");

        // THE VALUES. Constructed through the initialiser under test, then every scalar property read
        // back through its own accessor and compared with the value the same table says it was given.
        //
        // EACH CONSTRUCTOR IS CAUGHT, and the reason is that a raise is a FINDING ABOUT THE PORT and not
        // a reason to stop asking: which class, which selector, and what the exception says are the three
        // things needed to fix it, and an uncaught one takes the whole run down with a stack frame and no
        // name. So the name and the reason are recorded AND printed - recorded, because the comparison
        // should be able to see that this class did not round-trip, and printed, because the record is
        // the port's own and compare.py does not judge it.
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
        unsigned mismatches = entry->expectedCount;      // no object: nothing was read back
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
        // THE CHECK, and the record that carries it. Zero means every value went in under the property's
        // own name and came back out of that property's own accessor.


        // KVC, WHICH IS THE ONE MEMBER THE SDK DECLARES NO PROPERTY FOR. Measured on the host first:
        // class_copyIvarList on the host's own VTTemporalNoiseFilterConfiguration returns ten ivars and
        // the first is _sourcePixelFormat, so KVC on the host does NOT refuse the key - NSObject's
        // default implementation finds the ivar, strips the leading underscore and reads it. The port
        // therefore keeps the value in an IVAR of the same name, and this asks both sides the same
        // question and requires the same answer.
        //
        // The host side CANNOT be built through its designated initialiser: +isSupported is YES on this
        // Mac but +minimumDimensions and +maximumDimensions are 0 x 0, so the object is made through the
        // runtime instead. That is the runtime, and it compiles without a private header.
        Class kvcClass = NSClassFromString(@"CharonVTTemporalNoiseFilterConfiguration");
        if (!kvcClass)
            kvcClass = NSClassFromString(@"VTTemporalNoiseFilterConfiguration");
        OSType planted = (OSType)0x34323676;        // 'v624', so the answer is unmistakable
        NSString *kvcTag = @"kvc.VTTemporalNoiseFilterConfiguration.sourcePixelFormat";
        id kvcTarget = nil;
        if ([kvcClass isSubclassOfClass:NSClassFromString(@"CharonVTTemporalNoiseFilterConfiguration")]) {
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

        // THE SAME KVC QUESTION, asked of the HOST, because the port's answer is only right if the host's
        // is the same. The object is made through the runtime rather than through the designated
        // initialiser, because +isSupported is YES on this Mac while +minimumDimensions and
        // +maximumDimensions are 0 x 0 - so the documented way to build one cannot be used here, and
        // saying so is part of the answer.
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
