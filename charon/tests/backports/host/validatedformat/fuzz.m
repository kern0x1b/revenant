#import <Foundation/Foundation.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <unistd.h>

/* The port is compiled into this file under other selectors, so that the host's own methods stay the
   host's and the port's static functions are at hand to type the arguments. */
#define stringWithValidatedFormat charonHostStringWithValidatedFormat
#define localizedStringWithValidatedFormat charonHostLocalizedStringWithValidatedFormat
#define initWithValidatedFormat initWithCharonHostValidatedFormat
#include CHARON_VALIDATED_FORMAT
#undef stringWithValidatedFormat
#undef localizedStringWithValidatedFormat
#undef initWithValidatedFormat

static char c_string[64] = "x";
static uint64_t integer_word;
static BOOL localized;
static double floating_value;
static unichar wide_string[32] = {'x', 0};

static uint64_t state;

static uint32_t roll(uint32_t below)
{
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return (uint32_t)(state % below);
}

static struct {
    BOOL accented, positional, flags, width, star, precision, length, odd, pascalString, text, percent, unfinished;
} swarm;

static void choose_swarm(void)
{
    swarm.accented = roll(2);
    swarm.positional = roll(2);
    swarm.flags = roll(2);
    swarm.width = roll(2);
    swarm.star = roll(2);
    swarm.precision = roll(2);
    swarm.length = roll(2);
    swarm.odd = roll(2);
    swarm.pascalString = roll(2);
    swarm.text = roll(2);
    swarm.percent = roll(2);
    swarm.unfinished = roll(2);
}

static NSString *pick(NSArray *choices)
{
    return choices[roll((uint32_t)choices.count)];
}

static NSString *specifier(BOOL wild)
{
    NSMutableString *made = [NSMutableString stringWithString:@"%"];
    if (swarm.positional && roll(4) == 0)
        [made appendFormat:@"%u$", roll(wild ? 13 : 5)];
    if (swarm.flags && roll(4) == 0)
        [made appendString:pick(@[@"-", @"+", @" ", @"#", @"0"])];
    uint32_t width = roll(8), precision = roll(8);
    if (swarm.width && width == 0)
        [made appendString:@"10"];
    else if (swarm.star && width == 1 && wild)
        [made appendString:@"*"];
    else if (swarm.star && width == 2 && wild)
        [made appendFormat:@"*%u$", 1 + roll(3)];
    if (swarm.precision && precision == 0)
        [made appendString:@".2"];
    else if (swarm.star && swarm.precision && precision == 1 && wild)
        [made appendString:@".*"];
    if (swarm.length && roll(3) == 0)
        [made appendString:pick(@[@"h", @"hh", @"l", @"ll", @"q", @"L", @"j", @"z", @"t"])];
    uint32_t odd = wild ? roll(14) : 99;
    if (swarm.odd && odd == 0)
        return pick(@[@"%#@key@", @"%#@", @"%[k]@", @"%0$@", @"%13$d", @"%k", @"%y", @"%Z"]);
    [made appendString:swarm.pascalString && odd == 1 ? @"P" : pick(@[@"@", @"d", @"i", @"u", @"x", @"c", @"C", @"f", @"g", @"e", @"s", @"S", @"p", @"D", @"O", @"U", @"a"])];
    return made;
}

static NSString *format(BOOL wild)
{
    NSMutableString *made = [NSMutableString string];
    uint32_t count = roll(wild ? 6 : 4);
    for (uint32_t index = 0; index < count; index++) {
        uint32_t kind = roll(10);
        if (swarm.text && kind < 2)
            [made appendString:swarm.accented && roll(2) ? @" \u00e9 " : @" a "];
        else if (swarm.percent && kind == 2)
            [made appendString:@"%%"];
        else
            [made appendString:specifier(wild)];
    }
    if (swarm.unfinished && wild && roll(20) == 0)
        [made appendString:@"%"];
    return made;
}

/* One argument per slot, of the kind the allowed string gives that slot. Every argument is a word,
   which on arm64 is how a variadic argument of any of these kinds is passed. */
static void arguments_for(NSString *allowed, uint64_t *words)
{
    uint64_t floatingWord;
    memcpy(&floatingWord, &floating_value, sizeof floatingWord);
    for (int slot = 0; slot < 13; slot++)
        words[slot] = (uint64_t)(__bridge void *)@"object";
    NSArray *slots = charon_format_slots(allowed, NO);
    for (NSUInteger slot = 0; slot < slots.count && slot < 13; slot++) {
        if (![slots[slot] count])
            continue;
        switch ([slots[slot][0][0] unsignedIntegerValue]) {
            case CharonFormatObject: break;
            case CharonFormatCString: case CharonFormatPascalString: case CharonFormatPointer: case CharonFormatCount:
                words[slot] = (uint64_t)(void *)c_string;
                break;
            case CharonFormatWideString: words[slot] = (uint64_t)(void *)wide_string; break;
            case CharonFormatFloating: case CharonFormatLongFloating: words[slot] = floatingWord; break;
            default: words[slot] = integer_word; break;
        }
    }
}

/* Whether the arguments are those the allowed string describes, in a way that also holds for the format:
   only then is the output comparable, since the host reads eight bytes for every argument and the port
   reads what the allowed string says. */
static BOOL arguments_agree(NSString *wanted, NSString *allowed)
{
    NSArray *asked = charon_format_slots(wanted, NO), *offered = charon_format_slots(allowed, NO);
    for (NSArray *kinds in offered)
        for (NSArray *kind in kinds)
            if (![kind isEqual:kinds[0]])
                return NO;
    for (NSUInteger slot = 0; slot < asked.count; slot++) {
        if (slot >= offered.count || ![offered[slot] count])
            return NO;
        CharonFormatKind given = [offered[slot][0][0] unsignedIntegerValue];
        BOOL word = given == CharonFormatObject || given == CharonFormatCString || given == CharonFormatWideString
                 || given == CharonFormatPascalString || given == CharonFormatPointer;
        for (NSArray *kind in asked[slot]) {
            CharonFormatKind taken = [kind[0] unsignedIntegerValue];
            BOOL pointer = taken == CharonFormatCString || taken == CharonFormatWideString || taken == CharonFormatPascalString
                        || taken == CharonFormatPointer;
            if (taken == CharonFormatPointer && given == CharonFormatObject)
                return NO;
            if (taken != given && !(taken == CharonFormatWideCharacter && given == CharonFormatInteger) && !(word && pointer))
                return NO;
            if (![kind[1] isEqual:offered[slot][0][1]] && !pointer && !word)
                return NO;
        }
    }
    return YES;
}

static NSString *answer(BOOL ours, NSString *wanted, NSString *allowed, uint64_t *w)
{
    NSError *error = nil;
    NSString *made;
    if (localized)
        made = ours
            ? [NSString charonHostLocalizedStringWithValidatedFormat:wanted validFormatSpecifiers:allowed error:&error,
               w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9], w[10], w[11], w[12]]
            : [NSString localizedStringWithValidatedFormat:wanted validFormatSpecifiers:allowed error:&error,
               w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9], w[10], w[11], w[12]];
    else
        made = ours
            ? [NSString charonHostStringWithValidatedFormat:wanted validFormatSpecifiers:allowed error:&error,
               w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9], w[10], w[11], w[12]]
            : [NSString stringWithValidatedFormat:wanted validFormatSpecifiers:allowed error:&error,
               w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9], w[10], w[11], w[12]];
    return made ? [@"ok " stringByAppendingString:made] : [NSString stringWithFormat:@"%ld %@", (long)error.code, error.userInfo[NSDebugDescriptionErrorKey]];
}

static NSString *shown(NSString *text)
{
    NSMutableString *made = [NSMutableString string];
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar character = [text characterAtIndex:index];
        if (character >= 0x20 && character < 0x7f && character != '\\')
            [made appendFormat:@"%C", character];
        else
            [made appendFormat:@"\\u%04x", character];
    }
    return made;
}

static int check(NSString *wanted, NSString *allowed, NSString **report)
{
    uint64_t words[13];
    arguments_for(allowed, words);
    BOOL whole = arguments_agree(wanted, allowed);
    int pipes[2];
    pipe(pipes);
    pid_t child = fork();
    if (child == 0) {
        close(pipes[0]);
        dup2(open("/dev/null", O_WRONLY), 2);
        NSData *system = [answer(NO, wanted, allowed, words) dataUsingEncoding:NSUTF8StringEncoding];
        uint32_t length = (uint32_t)system.length;
        write(pipes[1], &length, sizeof length);
        write(pipes[1], system.bytes, system.length);
        NSString *port = answer(YES, wanted, allowed, words), *told = [[NSString alloc] initWithData:system encoding:NSUTF8StringEncoding];
        BOOL same = whole ? [told isEqual:port] : [told hasPrefix:@"ok "] == [port hasPrefix:@"ok "];
        NSData *verdict = [(same ? @"same" : [@"differ " stringByAppendingString:port]) dataUsingEncoding:NSUTF8StringEncoding];
        write(pipes[1], verdict.bytes, verdict.length);
        _exit(0);
    }
    close(pipes[1]);
    NSMutableData *received = [NSMutableData data];
    char buffer[4096];
    ssize_t got;
    while ((got = read(pipes[0], buffer, sizeof buffer)) > 0)
        [received appendBytes:buffer length:(NSUInteger)got];
    close(pipes[0]);
    int status = 0;
    waitpid(child, &status, 0);
    uint32_t length = 0;
    if (received.length < sizeof length)
        return -1;
    memcpy(&length, received.bytes, sizeof length);
    if (received.length < sizeof length + length)
        return -1;
    NSString *system = [[NSString alloc] initWithData:[received subdataWithRange:NSMakeRange(sizeof length, length)] encoding:NSUTF8StringEncoding];
    NSString *port = [[NSString alloc] initWithData:[received subdataWithRange:NSMakeRange(sizeof length + length, received.length - sizeof length - length)]
                                           encoding:NSUTF8StringEncoding];
    if ([port isEqual:@"same"])
        return whole ? 1 : 0;
    if ([port hasPrefix:@"differ "])
        port = [port substringFromIndex:7];
    else if (WIFSIGNALED(status))
        port = [NSString stringWithFormat:@"crashed with signal %d", WTERMSIG(status)];
    else
        port = @"ended without an answer";
    if (report)
        *report = [NSString stringWithFormat:@"[%@] against [%@]\n  system: %@\n  port:   %@", wanted, allowed, shown(system), shown(port)];
    return 2;
}

static NSString *shrink(NSString *text, BOOL (^still)(NSString *smaller))
{
    BOOL progress = YES;
    while (progress) {
        progress = NO;
        for (NSUInteger chunk = text.length; chunk >= 1 && !progress; chunk /= 2)
            for (NSUInteger start = 0; start + chunk <= text.length; start++) {
                NSString *smaller = [text stringByReplacingCharactersInRange:NSMakeRange(start, chunk) withString:@""];
                if (still(smaller)) {
                    text = smaller;
                    progress = YES;
                    break;
                }
            }
    }
    return text;
}

static NSString *smallest(NSString *wanted, NSString *allowed)
{
    NSString *report = nil;
    for (;;) {
        NSString *fixedAllowed = allowed;
        NSString *shorterWanted = shrink(wanted, ^BOOL(NSString *smaller) { return check(smaller, fixedAllowed, NULL) == 2; });
        NSString *shorterAllowed = shrink(allowed, ^BOOL(NSString *smaller) { return check(shorterWanted, smaller, NULL) == 2; });
        if ([shorterWanted isEqual:wanted] && [shorterAllowed isEqual:allowed])
            break;
        wanted = shorterWanted;
        allowed = shorterAllowed;
    }
    check(wanted, allowed, &report);
    return report;
}

int main(int argc, char **argv)
{
    int rounds = argc > 1 && atoi(argv[1]) > 0 ? atoi(argv[1]) : 20000, differ = 0, lost = 0, compared = 0;
    unsigned long long seed = argc > 2 ? strtoull(argv[2], NULL, 10) : 0;
    if (!seed)
        seed = 1 + arc4random();
    state = seed * 2654435761u + 1;
    printf("seed %llu\n", seed);
    NSMutableSet *seen = [NSMutableSet set];
    for (int round = 0; round < rounds; round++) @autoreleasepool {
        if (round % 50 == 0)
            choose_swarm();
        static const uint64_t integers[] = {7, 0, 65, 0xb0, 0xe9, 0xff, 0x2603, 0x1f600, (uint64_t)-1, 0x7fffffff, 1ull << 40};
        static const double floatings[] = {2.5, 0, -1.25, 1e300, 3.0e-7, 1.0 / 3};
        integer_word = integers[roll(sizeof integers / sizeof *integers)];
        floating_value = floatings[roll(sizeof floatings / sizeof *floatings)];
        localized = roll(4) == 0;
        NSString *allowed = format(NO), *wanted = roll(3) == 0 ? allowed : format(round % 3 == 0);
        NSString *report = nil;
        int result = check(wanted, allowed, &report);
        if (result == -1)
            lost++;
        else if (result == 1)
            compared++;
        else if (result == 2 && differ++ < 20) {
            NSString *least = smallest(wanted, allowed);
            if (![seen containsObject:least]) {
                [seen addObject:least];
                printf("FAIL %s\n  integer %#llx, float %g%s\n  smallest: %s\n", report.UTF8String, (unsigned long long)integer_word, floating_value, localized ? ", localized" : "", least.UTF8String);
            }
        }
    }
    printf("%d pairs, seed %llu, %d with the whole output compared, %d differ, %d lost to a crash of the host's formatting\n", rounds, seed, compared, differ, lost);
    return differ != 0;
}
