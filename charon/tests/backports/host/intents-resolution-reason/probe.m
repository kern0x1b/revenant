// probe.m - what the host RUNTIME answers for the resolution results of INIntentResolutionResult's factories, read by
// name: the three factories the 16.4 header declares (+needsValue, +notRequired, +unsupported), the two it does not
// (+unsupportedWithReason: and +confirmationRequiredWithItemToConfirm:forReason:), and the reader of each.
//
// Every selector is looked up at run time, so the header does not decide the answer. The readers are the four that
// the runtime's own class carries for these results: resolutionResultCode, itemToConfirm, unsupportedReason and
// confirmationReason. A reader that the class does not answer prints "absent", so the port's objects are compared on
// the same lines. Nothing here depends on the clock or on an address.
//
//   xcrun clang -fno-objc-arc -framework Foundation -framework Intents probe.m -o probe          (macOS)
//   xcrun clang -fno-objc-arc -target arm64-apple-ios15.0-macabi -isysroot $(xcrun --show-sdk-path) \
//       -iframework $(xcrun --show-sdk-path)/System/iOSSupport/System/Library/Frameworks \
//       -framework Foundation -framework Intents probe.m -o probe-catalyst
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <string.h>

#ifdef PORT
#define PREFIX "CharonHost"
#else
#define PREFIX ""
#endif

static Class charonClass(NSString *name)
{
    return NSClassFromString([NSString stringWithFormat:@"%s%@", PREFIX, name]);
}

static const char *className(id object)
{
    const char *name = class_getName([object class]);
    size_t prefix = strlen(PREFIX);
    return strncmp(name, PREFIX, prefix) == 0 ? name + prefix : name;
}

static void readAnswers(id result)
{
    static NSString *const readers[] = { @"resolutionResultCode", @"itemToConfirm", @"unsupportedReason", @"confirmationReason", @"disambiguationItems" };
    for (size_t i = 0; i < sizeof(readers) / sizeof(readers[0]); i++) {
        SEL getter = NSSelectorFromString(readers[i]);
        if (![result respondsToSelector:getter]) {
            printf("  %s\tabsent\n", [readers[i] UTF8String]);
            continue;
        }
        id value = [result valueForKey:readers[i]];
        if (!value) {
            printf("  %s\tnil\n", [readers[i] UTF8String]);
        } else if ([value isKindOfClass:[NSNumber class]]) {
            printf("  %s\tnumber %ld\n", [readers[i] UTF8String], (long)[value integerValue]);
        } else if ([value isKindOfClass:[NSString class]]) {
            printf("  %s\tstring %s\n", [readers[i] UTF8String], [value UTF8String]);
        } else {
            printf("  %s\t%s\n", [readers[i] UTF8String], className(value));
        }
    }
}

static void answer(NSString *label, id result)
{
    printf("%s\t%s\n", [label UTF8String], result ? className(result) : "nil");
    if (result) {
        readAnswers(result);
    }
}

int main(void)
{
    @autoreleasepool {
        Class resultClass = charonClass(@"INIntentResolutionResult");

        answer(@"+needsValue", [resultClass needsValue]);
        answer(@"+notRequired", [resultClass notRequired]);
        answer(@"+unsupported", [resultClass unsupported]);

        SEL unsupported = NSSelectorFromString(@"unsupportedWithReason:");
        for (NSInteger reason = 0; reason <= 2; reason++) {
            if (![resultClass respondsToSelector:unsupported]) {
                printf("+unsupportedWithReason:%ld\tabsent\n", (long)reason);
                break;
            }
            id result = ((id (*)(id, SEL, NSInteger))objc_msgSend)(resultClass, unsupported, reason);
            answer([NSString stringWithFormat:@"+unsupportedWithReason:%ld", (long)reason], result);
        }

        SEL confirm = NSSelectorFromString(@"confirmationRequiredWithItemToConfirm:forReason:");
        if (![resultClass respondsToSelector:confirm]) {
            printf("+confirmationRequiredWithItemToConfirm:forReason:\tabsent\n");
        } else {
            id dinner = ((id (*)(id, SEL, id, NSInteger))objc_msgSend)(resultClass, confirm, @"Dinner", 7);
            answer(@"+confirmationRequiredWithItemToConfirm:Dinner forReason:7", dinner);
            id nothing = ((id (*)(id, SEL, id, NSInteger))objc_msgSend)(resultClass, confirm, nil, 0);
            answer(@"+confirmationRequiredWithItemToConfirm:nil forReason:0", nothing);
        }

        // The factories of the subclasses that answer the other two shapes, so every reader is read on each shape.
        Class integerClass = charonClass(@"INIntegerResolutionResult");
        SEL success = NSSelectorFromString(@"successWithResolvedValue:");
        answer(@"INIntegerResolutionResult +successWithResolvedValue:7",
               ((id (*)(id, SEL, NSInteger))objc_msgSend)(integerClass, success, 7));
        SEL valueConfirm = NSSelectorFromString(@"confirmationRequiredWithValueToConfirm:");
        answer(@"INIntegerResolutionResult +confirmationRequiredWithValueToConfirm:3",
               ((id (*)(id, SEL, id))objc_msgSend)(integerClass, valueConfirm, @3));
        Class speakableClass = charonClass(@"INSpeakableStringResolutionResult");
        Class stringClass = charonClass(@"INSpeakableString");
        id speakable = ((id (*)(id, SEL, id))objc_msgSend)([stringClass alloc], NSSelectorFromString(@"initWithSpokenPhrase:"), @"Ann");
        id other = ((id (*)(id, SEL, id))objc_msgSend)([stringClass alloc], NSSelectorFromString(@"initWithSpokenPhrase:"), @"Bob");
        // An empty array is not read here: the host answers nil for it, and the port's generated factory answers an
        // object, which facts/Intents/Intents.md records as the gap it is (the generated row is not this pair's).
        SEL disambiguation = NSSelectorFromString(@"disambiguationWithStringsToDisambiguate:");
        answer(@"INSpeakableStringResolutionResult +disambiguationWithStringsToDisambiguate:[Ann]",
               ((id (*)(id, SEL, id))objc_msgSend)(speakableClass, disambiguation, @[speakable]));
        id two = ((id (*)(id, SEL, id))objc_msgSend)(speakableClass, disambiguation, @[speakable, other]);
        answer(@"INSpeakableStringResolutionResult +disambiguationWithStringsToDisambiguate:[Ann, Bob]", two);
    }
    return 0;
}
