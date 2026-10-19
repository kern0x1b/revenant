#import <Foundation/Foundation.h>
#import "check.h"
#import <objc/message.h>

static uint64_t state = 0x51ED270B0B1F00Dull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *safely(NSString *(^block)(void))
{
    @try {
        return block() ?: @"(nil)";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raises %@", exception.name];
    }
}

static id random_item(void)
{
    NSArray *words = @[@"A", @"B", @"apple", @"Ivan", @"Isabel", @"hijo", @"Ana", @"ocho", @"one", @"абв", @"אב", @"الع", @"中文", @"\U0001F600", @"", @"x y", @"Zoe", @"Émile", @"oak", @"uno", @"Hana", @"Oscar", @"Eva", @"Ωμέγα", @"हिन्दी", @"Alpha"];
    switch (next() % 12) {
    case 0: return @(next() % 1000);
    case 1: return @((double)(next() % 100000) / 100.0);
    case 2: return [NSNull null];
    case 3: return [NSURL URLWithString:@"http://example.com/a"];
    case 4: return @(next() % 2 == 0);
    case 5: return [NSDate dateWithTimeIntervalSince1970:next() % 100000000];
    default: return words[next() % words.count];
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostNSListFormatter");
        CHECK(ours != Nil, "the port defines the class");
        id fresh = [[ours alloc] init];
        NSListFormatter *theirs = [[NSListFormatter alloc] init];
        CHECK_EQUAL([[fresh locale] localeIdentifier], [[theirs locale] localeIdentifier], "the locale starts as the current one");
        CHECK([fresh itemFormatter] == nil && theirs.itemFormatter == nil, "there is no item formatter to begin with");
        [fresh setLocale:[NSLocale localeWithLocaleIdentifier:@"de_DE"]];
        [theirs setLocale:[NSLocale localeWithLocaleIdentifier:@"de_DE"]];
        [fresh setLocale:nil];
        [theirs setLocale:nil];
        CHECK_EQUAL([[fresh locale] localeIdentifier], [[theirs locale] localeIdentifier], "a nil locale puts the current one back");
        NSNumberFormatter *number = [[NSNumberFormatter alloc] init];
        number.numberStyle = NSNumberFormatterSpellOutStyle;
        [fresh setItemFormatter:number];
        CHECK([[fresh itemFormatter] isKindOfClass:[NSNumberFormatter class]] && [fresh itemFormatter] != number, "the item formatter is copied");
        [fresh setLocale:[NSLocale localeWithLocaleIdentifier:@"fr_FR"]];
        id copied = [fresh copy];
        CHECK([copied class] == ours && [[[copied locale] localeIdentifier] isEqualToString:@"fr_FR"] && [copied itemFormatter] != nil, "a copy keeps the locale and the item formatter");
        CHECK([fresh stringFromItems:nil] == nil && [theirs stringFromItems:nil] == nil, "no items have no string");
        CHECK_EQUAL([fresh stringFromItems:@[]], [theirs stringFromItems:@[]], "no items in an array have the empty string");
        CHECK([fresh stringForObjectValue:@"text"] == nil && [fresh stringForObjectValue:[NSSet setWithObject:@"a"]] == nil && [fresh stringForObjectValue:nil] == nil, "only an array has a string");
        CHECK_EQUAL(safely(^{ return [NSListFormatter localizedStringByJoiningStrings:@[@"a", @"b", @"c"]]; }), safely(^{ return ((id (*)(id, SEL, id))objc_msgSend)(ours, @selector(localizedStringByJoiningStrings:), @[@"a", @"b", @"c"]); }), "the class method joins with the current locale");

        NSArray *identifiers = [NSLocale availableLocaleIdentifiers];
        NSArray *extra = @[@"en-GB", @"en_US@calendar=buddhist", @"zh-Hant-TW", @"zh_Hant_HK", @"sr_Latn_RS", @"en_US_POSIX", @"zz", @"xx_YY", @"pt-PT", @"de_CH", @"fr_CA", @"es_419", @"en_GB@rg=uszzzz", @"ja_JP@rg=gbzzzz", @"nb_NO", @"no", @"iw", @"in_ID", @"az_Cyrl_AZ", @"ti_ET"];
        NSUInteger cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 40000;
        NSUInteger wrong = 0;
        NSMutableArray *samples = [NSMutableArray array];
        NSMutableDictionary *byLocale = [NSMutableDictionary dictionary];
        for (NSUInteger index = 0; index < cases; index++) {
            NSString *identifier = next() % 5 == 0 ? extra[next() % extra.count] : identifiers[next() % identifiers.count];
            NSLocale *locale = [NSLocale localeWithLocaleIdentifier:identifier];
            NSMutableArray *items = [NSMutableArray array];
            NSUInteger count = next() % 7;
            for (NSUInteger item = 0; item < count; item++)
                [items addObject:random_item()];
            id one = [[ours alloc] init];
            NSListFormatter *two = [[NSListFormatter alloc] init];
            [one setLocale:locale];
            two.locale = locale;
            if (next() % 4 == 0) {
                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                formatter.numberStyle = (NSNumberFormatterStyle)(next() % 6);
                [one setItemFormatter:formatter];
                two.itemFormatter = formatter;
            } else if (next() % 9 == 0) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateStyle = (NSDateFormatterStyle)(next() % 4);
                [one setItemFormatter:formatter];
                two.itemFormatter = formatter;
            }
            NSString *a = safely(^{ return [one stringFromItems:items]; });
            NSString *b = safely(^{ return [two stringFromItems:items]; });
            if (![a isEqualToString:b]) {
                wrong++;
                byLocale[identifier] = @([byLocale[identifier] integerValue] + 1);
                if (samples.count < 12)
                    [samples addObject:[NSString stringWithFormat:@"%@ %@\n     port   %@\n     system %@", identifier, items, a, b]];
            }
        }
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        for (NSString *key in [[byLocale allKeys] sortedArrayUsingSelector:@selector(compare:)])
            printf("  differs in %s: %ld\n", key.UTF8String, (long)[byLocale[key] integerValue]);
        charon_check(wrong == 0, "the port joins random lists in random locales as the system does", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)cases]);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
