#import "fuzz.h"

static uint64_t fuzz_state;
static NSMutableDictionary<NSString *, NSNumber *> *fuzz_counts;
static NSMutableDictionary<NSString *, NSString *> *fuzz_tolerated;
static NSMutableSet<NSString *> *fuzz_shown;
static int fuzz_rounds;
static unsigned long long fuzz_seed;

void fuzz_start(int argc, char **argv, int *rounds)
{
    fuzz_seed = argc > 2 ? strtoull(argv[2], NULL, 10) : 0;
    if (!fuzz_seed)
        fuzz_seed = 1 + arc4random();
    fuzz_state = fuzz_seed * 2654435761u + 1;
    if (argc > 1 && atoi(argv[1]) > 0)
        *rounds = atoi(argv[1]);
    fuzz_rounds = *rounds;
    fuzz_counts = [NSMutableDictionary dictionary];
    fuzz_shown = [NSMutableSet set];
    fuzz_tolerated = [NSMutableDictionary dictionary];
    const char *tolerated = getenv("FUZZ_TOLERATED");
    NSString *list = tolerated ? [NSString stringWithContentsOfFile:@(tolerated) encoding:NSUTF8StringEncoding error:NULL] : nil;
    for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
        if (!line.length || [line hasPrefix:@"#"])
            continue;
        NSRange tab = [line rangeOfString:@"\t"];
        if (tab.location != NSNotFound)
            fuzz_tolerated[[line substringToIndex:tab.location]] = [line substringFromIndex:NSMaxRange(tab)];
    }
    printf("seed %llu, %d rounds\n", fuzz_seed, fuzz_rounds);
}

uint32_t fuzz_roll(uint32_t below)
{
    fuzz_state ^= fuzz_state << 13;
    fuzz_state ^= fuzz_state >> 7;
    fuzz_state ^= fuzz_state << 17;
    return below ? (uint32_t)(fuzz_state % below) : 0;
}

void fuzz_compare(NSString *category, NSString *what, NSString *system, NSString *port)
{
    if ([system isEqual:port])
        return;
    fuzz_counts[category] = @(fuzz_counts[category].integerValue + 1);
    NSUInteger shown = 0;
    for (NSString *seen in fuzz_shown)
        if ([seen hasPrefix:[category stringByAppendingString:@"\t"]])
            shown++;
    if (shown < 3) {
        [fuzz_shown addObject:[NSString stringWithFormat:@"%@\t%lu", category, (unsigned long)shown]];
        printf("DIFF %s: %s\n  system: %s\n  port:   %s\n", category.UTF8String, what.UTF8String, system.UTF8String, port.UTF8String);
    }
}

int fuzz_finish(void)
{
    int failing = 0;
    for (NSString *category in [fuzz_counts.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *reason = fuzz_tolerated[category];
        printf("%s %s: %ld differ%s%s\n", reason ? "tolerated" : "FAIL", category.UTF8String, (long)fuzz_counts[category].integerValue,
               reason ? " - " : "", reason ? reason.UTF8String : "");
        if (!reason)
            failing++;
    }
    printf("%d rounds, seed %llu, %lu categories differ, %d not tolerated\n", fuzz_rounds, fuzz_seed, (unsigned long)fuzz_counts.count, failing);
    NSUInteger singletons = 0;
    for (NSNumber *count in fuzz_counts.allValues)
        if (count.integerValue == 1)
            singletons++;
    if (fuzz_counts.count)
        printf("hint: %lu/%lu categories differed exactly once - a rough long-tail signal, not a Good-Turing estimate "
               "(categories are not independent draws here) and not a stopping rule\n",
               (unsigned long)singletons, (unsigned long)fuzz_counts.count);
    return failing != 0;
}
