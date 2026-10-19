#import <Foundation/Foundation.h>

void host_attach_prefixed(const char *prefix);

static NSString *answer(NSTextCheckingResult *result, SEL selector, NSString *name)
{
    @try {
        NSRange range = ((NSRange (*)(id, SEL, NSString *))[result methodForSelector:selector])(result, selector, name);
        return range.location == NSNotFound ? [NSString stringWithFormat:@"{NSNotFound, %lu}", (unsigned long)range.length] : NSStringFromRange(range);
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raises %@", exception.name];
    }
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        NSArray *cases = @[
            @[@"(?<word>a+)(b)?", @0, @"xaab", @[@"word", @"missing", @"", @"1", @"Word"]],
            @[@"(x)(?<second>y)?(?<third>z)", @0, @"xz", @[@"second", @"third", @"x"]],
            @[@"(?:q)(?<n>r)(?=s)", @0, @"qrs", @[@"n", @"q"]],
            @[@"(?<outer>a(?<inner>b))c", @0, @"abc", @[@"outer", @"inner"]],
            @[@"(?<w> a ) # (?<fake>x)\n(?<real>b)", @(NSRegularExpressionAllowCommentsAndWhitespace), @"ab", @[@"w", @"fake", @"real"]],
            @[@"(?<w>a)", @(NSRegularExpressionIgnoreMetacharacters), @"(?<w>a)", @[@"w"]],
            @[@"(?<w>A)(?<v>b)", @(NSRegularExpressionCaseInsensitive), @"aB", @[@"w", @"v"]],
            @[@"(?<=x)(?<after>y)(?<!z)", @0, @"xy", @[@"after"]],
            @[@"[(?<no>x)](?<yes>y)", @0, @"xy", @[@"no", @"yes"]],
            @[@"\\Q(?<no>\\E(?<yes>y)", @0, @"(?<no>y", @[@"no", @"yes"]],
            @[@"(a)", @0, @"a", @[@"a"]],
        ];
        int failures = 0, checks = 0;
        for (NSArray *entry in cases) {
            NSError *error = nil;
            NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:entry[0] options:[entry[1] unsignedIntegerValue] error:&error];
            if (!expression) {
                failures++;
                printf("FAIL %s does not compile on this host: %s\n", [entry[0] UTF8String], error.description.UTF8String);
                continue;
            }
            NSString *string = entry[2];
            NSTextCheckingResult *match = [expression firstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
            if (!match) {
                failures++;
                printf("FAIL %s finds no match in %s\n", [entry[0] UTF8String], string.UTF8String);
                continue;
            }
            NSArray *results = @[match, [match resultByAdjustingRangesWithOffset:3]];
            for (NSUInteger variant = 0; variant < results.count; variant++) {
                for (NSString *name in entry[3]) {
                    for (int repeat = 0; repeat < 2; repeat++) {
                        NSString *system = answer(results[variant], @selector(rangeWithName:), name);
                        NSString *ours = answer(results[variant], NSSelectorFromString(@"charonHost_rangeWithName:"), name);
                        checks++;
                        if ([system isEqual:ours]) {
                            printf("ok   %s%s [%s]: %s\n", [entry[0] UTF8String], variant ? " shifted" : "", name.UTF8String, system.UTF8String);
                        } else {
                            failures++;
                            printf("FAIL %s%s [%s]: the system answers %s, the backport answers %s\n", [entry[0] UTF8String], variant ? " shifted" : "", name.UTF8String, system.UTF8String, ours.UTF8String);
                        }
                    }
                }
            }
        }
        NSTextCheckingResult *spelling = [NSTextCheckingResult spellCheckingResultWithRange:NSMakeRange(1, 2)];
        NSTextCheckingResult *plain = [[NSRegularExpression regularExpressionWithPattern:@"(?<w>a)" options:0 error:NULL] firstMatchInString:@"a" options:0 range:NSMakeRange(0, 1)];
        NSArray *odd = @[@[spelling, @"w"], @[plain, [NSNull null]]];
        for (NSArray *entry in odd) {
            NSString *name = entry[1] == [NSNull null] ? nil : entry[1];
            NSString *system = answer(entry[0], @selector(rangeWithName:), name);
            NSString *ours = answer(entry[0], NSSelectorFromString(@"charonHost_rangeWithName:"), name);
            checks++;
            if ([system isEqual:ours]) {
                printf("ok   %s [%s]: %s\n", NSStringFromClass([entry[0] class]).UTF8String, (name ?: @"nil").UTF8String, system.UTF8String);
            } else {
                failures++;
                printf("FAIL %s [%s]: the system answers %s, the backport answers %s\n", NSStringFromClass([entry[0] class]).UTF8String, (name ?: @"nil").UTF8String, system.UTF8String, ours.UTF8String);
            }
        }
        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
