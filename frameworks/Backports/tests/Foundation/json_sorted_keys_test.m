#import <Foundation/Foundation.h>

NSData *revenant_sorted_keys_data(id object, NSUInteger options, NSError **error);

static NSArray *cases(void)
{
    NSArray *unicodeNames = @[
        [NSString stringWithCharacters:(const unichar[]){0x00e9} length:1],
        [NSString stringWithCharacters:(const unichar[]){0xff01} length:1],
        [NSString stringWithCharacters:(const unichar[]){0xe000} length:1],
        [NSString stringWithCharacters:(const unichar[]){0xd83d, 0xde00} length:2],
        @"a", @"A", @"_", @"z",
    ];
    NSDictionary *unicodeKeys = [NSDictionary dictionaryWithObjects:@[@1, @2, @3, @4, @5, @6, @7, @8] forKeys:unicodeNames];
    NSArray *hardWords = @[@"a", @"A", @"b", @"B", @"_", @"-", @"1", @"10", @"9", @"aa", @"Aa", @"aA", @"", @" ", @"z", @"Z", @"\U000000e9", @"e", @"\U000000c9", @"e\U00000301", @"\U000000df", @"ss", @"\U0000017f", @"\U000065e5\U0000672c", @"\U00003042", @"\U000030a2", @"!", @"\U0000ff01", @"\U0001F600", @"zebra", @"apple", @"Apple", @"key with space", @"key_with_underscore", @"x.y", @"x/y", @"x-y", @"\U000000e4", @"\U000000f6", @"\U000000f8", @"\U000000d8", @"\U00000142", @"\U00000141"];
    NSMutableDictionary *hard = [NSMutableDictionary dictionary];
    for (NSString *word in hardWords) hard[word] = @1;
    NSDictionary *nested = @{@"b": @[@{}, @[], @[@"x", @{@"k": NSNull.null}]], @"a": @{@"inner": @{}, @"empty": @[]}};
    NSArray *numbers = @[@1, @1.5, @1e20, @-0.0, @123456789.125, @1e-7, @(INT64_MAX), @(INT64_MIN), @0, @YES, @NO, NSNull.null];
    NSDictionary *escapes = @{@"slash": [@"a/b\"c\\d\n\t" stringByAppendingString:[NSString stringWithCharacters:(const unichar[]){1} length:1]], @"quote": @"\"", @"unicode": @"é ！ 😀", @"/": @"/"};
    return @[
        @{},
        @[],
        @{@"only": @[]},
        unicodeKeys,
        hard,
        nested,
        @{@"numbers": numbers},
        escapes,
        @[unicodeKeys, nested, escapes],
        @{@"deep": @{@"l1": @{@"l2": @{@"l3": @[@1, @{@"z": @0, @"y": @[NSNull.null]}]}}}},
        @"top-level string",
        @42,
        NSNull.null,
    ];
}

int main(void)
{
    NSUInteger failures = 0;
    NSUInteger checked = 0;
    NSArray *optionSets = @[@(NSJSONWritingSortedKeys), @(NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted), @(NSJSONWritingSortedKeys | NSJSONWritingFragmentsAllowed), @(NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted | NSJSONWritingFragmentsAllowed)];
    for (id object in cases()) {
        for (NSNumber *option in optionSets) {
            NSUInteger options = option.unsignedIntegerValue;
            BOOL container = [object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSArray class]];
            if (!container && !(options & NSJSONWritingFragmentsAllowed))
                continue;
            NSError *appleError = nil;
            NSError *ourError = nil;
            NSData *apple = [NSJSONSerialization dataWithJSONObject:object options:options error:&appleError];
            NSData *ours = revenant_sorted_keys_data(object, options, &ourError);
            checked++;
            if (apple == nil || ours == nil) {
                if ((apple == nil) != (ours == nil)) {
                    failures++;
                    printf("DIFFERENT failure: options=%lu apple=%s ours=%s\n", (unsigned long)options, appleError ? "error" : "ok", ourError ? "error" : "ok");
                }
                continue;
            }
            if (![apple isEqualToData:ours]) {
                failures++;
                printf("DIFFERENT options=%lu\n--- apple\n%s\n--- ours\n%s\n", (unsigned long)options,
                       [[[NSString alloc] initWithData:apple encoding:NSUTF8StringEncoding] UTF8String],
                       [[[NSString alloc] initWithData:ours encoding:NSUTF8StringEncoding] UTF8String]);
            }
        }
    }
    NSArray *pool = @[@"a", @"A", @"b", @"Z", @"z", @"0", @"1", @"9", @"10", @"_", @"-", @".", @"/", @" ", @"", @"\U000000e9", @"e\U00000301", @"\U000000c9", @"\U000000df", @"\U0000ff01", @"\U0001F600", @"\U000065e5", @"\U00003042", @"\U0000017f", @"x y", @"key_1", @"key_10", @"key_9"];
    srandom(20261022);
    for (NSUInteger trial = 0; trial < 300; trial++) {
        NSMutableDictionary *sample = [NSMutableDictionary dictionary];
        NSUInteger size = 1 + random() % 12;
        for (NSUInteger i = 0; i < size; i++)
            sample[pool[random() % pool.count]] = @(i);
        for (NSNumber *option in optionSets) {
            NSUInteger options = option.unsignedIntegerValue;
            NSData *apple = [NSJSONSerialization dataWithJSONObject:sample options:options error:nil];
            NSData *ours = revenant_sorted_keys_data(sample, options, nil);
            checked++;
            if (![apple isEqualToData:ours]) {
                failures++;
                printf("DIFFERENT random trial=%lu options=%lu\n", (unsigned long)trial, (unsigned long)options);
            }
        }
    }
    printf("checked %lu, differences %lu\n", (unsigned long)checked, (unsigned long)failures);
    return failures == 0 ? 0 : 1;
}
