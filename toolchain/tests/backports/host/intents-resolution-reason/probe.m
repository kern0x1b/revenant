#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <string.h>

#ifdef PORT
#define PREFIX "RevenantHost"
#else
#define PREFIX ""
#endif

static Class revenantClass(NSString *name)
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
        Class resultClass = revenantClass(@"INIntentResolutionResult");

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

        Class integerClass = revenantClass(@"INIntegerResolutionResult");
        SEL success = NSSelectorFromString(@"successWithResolvedValue:");
        answer(@"INIntegerResolutionResult +successWithResolvedValue:7",
               ((id (*)(id, SEL, NSInteger))objc_msgSend)(integerClass, success, 7));
        SEL valueConfirm = NSSelectorFromString(@"confirmationRequiredWithValueToConfirm:");
        answer(@"INIntegerResolutionResult +confirmationRequiredWithValueToConfirm:3",
               ((id (*)(id, SEL, id))objc_msgSend)(integerClass, valueConfirm, @3));
        Class speakableClass = revenantClass(@"INSpeakableStringResolutionResult");
        Class stringClass = revenantClass(@"INSpeakableString");
        id speakable = ((id (*)(id, SEL, id))objc_msgSend)([stringClass alloc], NSSelectorFromString(@"initWithSpokenPhrase:"), @"Ann");
        id other = ((id (*)(id, SEL, id))objc_msgSend)([stringClass alloc], NSSelectorFromString(@"initWithSpokenPhrase:"), @"Bob");
        SEL disambiguation = NSSelectorFromString(@"disambiguationWithStringsToDisambiguate:");
        answer(@"INSpeakableStringResolutionResult +disambiguationWithStringsToDisambiguate:[Ann]",
               ((id (*)(id, SEL, id))objc_msgSend)(speakableClass, disambiguation, @[speakable]));
        id two = ((id (*)(id, SEL, id))objc_msgSend)(speakableClass, disambiguation, @[speakable, other]);
        answer(@"INSpeakableStringResolutionResult +disambiguationWithStringsToDisambiguate:[Ann, Bob]", two);
    }
    return 0;
}
