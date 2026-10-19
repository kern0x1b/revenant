#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

void host_attach_prefixed(const char *prefix);

static int charon_divergences;

static SEL ported(const char *selector)
{
    return NSSelectorFromString([NSString stringWithFormat:@"charonHost_%s", selector]);
}

static void note(NSString *label, id system, id ours)
{
    printf("note %s: the system %@, the backport %@\n", label.UTF8String,
           system ? [system description] : @"(nil)", ours ? [ours description] : @"(nil)");
    fflush(stdout);
}

static void progress_state(void)
{
    printf("--- NSProgress\n");
    struct { const char *label; long long total; long long done; } cases[] = {
        {"no units", 0, 0}, {"one of none", 0, 1}, {"ten of ten", 10, 10}, {"half of ten", 10, 5},
        {"a hundred", 100, 1}, {"negative total", -1, 0}, {"negative done", 10, -1},
    };
    for (NSUInteger index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
        NSProgress *system = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        system.totalUnitCount = cases[index].total;
        system.completedUnitCount = cases[index].done;
        NSProgress *ours = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        ours.totalUnitCount = cases[index].total;
        ours.completedUnitCount = cases[index].done;
        charon_check(system.isIndeterminate ==
                      ((BOOL (*)(id, SEL))objc_msgSend)(ours, ported("isIndeterminate")),
                      cases[index].label,
                      [NSString stringWithFormat:@"the system answers %d, the backport answers %d",
                       (int)system.isIndeterminate,
                       (int)((BOOL (*)(id, SEL))objc_msgSend)(ours, ported("isIndeterminate"))]);
    }
    NSProgress *system = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    [system pause];
    NSProgress *ours = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    ((void (*)(id, SEL, id))objc_msgSend)(ours, ported("setResumingHandler:"), ^{ });
    charon_check(((BOOL (*)(id, SEL))objc_msgSend)(ours, ported("isPaused")) == NO,
                 "a fresh progress is not paused on the backport side",
                 @"the backport says a fresh progress is paused");
    __block int systemRan = 0, ourRan = 0;
    system.resumingHandler = ^{ systemRan++; };
    ((void (*)(id, SEL, id))objc_msgSend)(ours, ported("setResumingHandler:"), ^{ ourRan++; });
    [system resume];
    ((void (*)(id, SEL))objc_msgSend)(ours, ported("resume"));
    charon_check(systemRan == ourRan, "-resume on a progress that was not paused runs the handler the same number of times",
                 [NSString stringWithFormat:@"the system runs it %d times, the backport %d", systemRan, ourRan]);
    charon_check(((BOOL (*)(id, SEL))objc_msgSend)(ours, ported("isPaused")) == NO,
                 "and the backport is not paused afterwards", @"the backport is paused after -resume");
}

static void number_formatter(void)
{
    printf("--- NSNumberFormatter\n");
    for (NSString *identifier in @[@"en_US", @"de_DE", @"fr_FR"]) {
        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:identifier];
        for (NSUInteger digits = 0; digits < 5; digits++) {
            NSNumberFormatter *system = [[NSNumberFormatter alloc] init];
            system.locale = locale;
            system.numberStyle = NSNumberFormatterDecimalStyle;
            system.minimumGroupingDigits = digits;
            NSNumberFormatter *ours = [[NSNumberFormatter alloc] init];
            ours.locale = locale;
            ours.numberStyle = NSNumberFormatterDecimalStyle;
            ((void (*)(id, SEL, NSUInteger))objc_msgSend)(ours, ported("setMinimumGroupingDigits:"), digits);
            charon_check(system.minimumGroupingDigits ==
                          ((NSUInteger (*)(id, SEL))objc_msgSend)(ours, ported("minimumGroupingDigits")),
                          [[NSString stringWithFormat:@"%@ minimumGroupingDigits at %lu digits", identifier,
                            (unsigned long)digits] UTF8String], @"the two sides keep different values");
            for (NSNumber *number in @[@123, @1234, @12345, @1234567, @(-1234.5)]) {
                NSString *systemText = [system stringFromNumber:number];
                NSString *ourText = ((id (*)(id, SEL, id))objc_msgSend)(ours, ported("stringFromNumber:"), number);
                charon_check([systemText isEqualToString:ourText],
                             [[NSString stringWithFormat:@"%@ %@ at %lu digits", identifier, number,
                               (unsigned long)digits] UTF8String],
                             [NSString stringWithFormat:@"the system writes %@, the backport writes %@",
                              systemText, ourText]);
            }
        }
        NSNumberFormatter *system = [[NSNumberFormatter alloc] init];
        NSNumberFormatter *ours = [[NSNumberFormatter alloc] init];
        system.formattingContext = NSFormattingContextStandalone;
        ((void (*)(id, SEL, NSFormattingContext))objc_msgSend)(ours, ported("setFormattingContext:"),
                                                               NSFormattingContextStandalone);
        charon_check(system.formattingContext == ((NSFormattingContext (*)(id, SEL))objc_msgSend)(ours, ported("formattingContext")),
                     [[NSString stringWithFormat:@"%@ keeps the formatting context", identifier] UTF8String],
                     @"the two sides keep different contexts");
    }
}

static void url_encoding(void)
{
    printf("--- the URL encoders\n");
    NSArray *strings = @[@"https://example.com/a b", @"https://example.com/a%20b", @"https://example.com/",
                         @"https://user:pw@host.example:8443/p?q=1#f", @"https://example.com/ünïcode",
                         @"not a url at all", @""];
    for (NSString *text in strings) {
        NSURL *system = [NSURL URLWithString:text encodingInvalidCharacters:YES];
        NSURL *ours = ((id (*)(id, SEL, id, BOOL))objc_msgSend)([NSURL class],
                      ported("URLWithString:encodingInvalidCharacters:"), text, (BOOL)YES);
        charon_check((system == nil) == (ours == nil) &&
                      [system.absoluteString isEqualToString:ours.absoluteString],
                     [[NSString stringWithFormat:@"the escaped URL of %@", text] UTF8String],
                     [NSString stringWithFormat:@"the system answers %@, the backport answers %@",
                      system.absoluteString, ours.absoluteString]);
        NSURL *systemRaw = [NSURL URLWithString:text encodingInvalidCharacters:NO];
        NSURL *ourRaw = ((id (*)(id, SEL, id, BOOL))objc_msgSend)([NSURL class],
                         ported("URLWithString:encodingInvalidCharacters:"), text, (BOOL)NO);
        charon_check((systemRaw == nil) == (ourRaw == nil),
                     [[NSString stringWithFormat:@"the unescaped reading of %@", text] UTF8String],
                     [NSString stringWithFormat:@"the system answers %@, the backport answers %@",
                      systemRaw ? systemRaw.absoluteString : @"(nil)", ourRaw ? ourRaw.absoluteString : @"(nil)"]);
    }
}

static void promised_item(void)
{
    printf("--- the promised item\n");
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-promised.txt"];
    [@"hello" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    for (NSString *candidate in @[path, [path stringByAppendingString:@"-missing"]]) {
        NSURL *file = [NSURL fileURLWithPath:candidate];
        NSError *systemError = nil, *ourError = nil;
        id systemValue = nil;
        id ourSlot = nil;
        BOOL systemRead = [file getPromisedItemResourceValue:&systemValue forKey:NSURLFileSizeKey error:&systemError];
        BOOL ourRead = ((BOOL (*)(id, SEL, id *, id, NSError **))objc_msgSend)(file,
                        ported("getPromisedItemResourceValue:forKey:error:"), &ourSlot, NSURLFileSizeKey, &ourError);
        charon_check(systemRead == ourRead && (systemValue == ourSlot || [systemValue isEqual:ourSlot]),
                     [[NSString stringWithFormat:@"the promised size of %@", candidate.lastPathComponent] UTF8String],
                     [NSString stringWithFormat:@"the system answers %d/%@, the backport answers %d/%@",
                      (int)systemRead, systemValue, (int)ourRead, ourSlot]);
        charon_check((!systemError && !ourError) ||
                      ([systemError.domain isEqualToString:ourError.domain] && systemError.code == ourError.code),
                     [[NSString stringWithFormat:@"the promised error of %@", candidate.lastPathComponent] UTF8String],
                     [NSString stringWithFormat:@"the system answers %@ (%ld), the backport answers %@ (%ld)",
                      systemError.domain, (long)systemError.code, ourError.domain, (long)ourError.code]);
        BOOL systemReachable = [file checkPromisedItemIsReachableAndReturnError:NULL];
        BOOL ourReachable = ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(file,
                              ported("checkPromisedItemIsReachableAndReturnError:"), NULL);
        charon_check(systemReachable == ourReachable,
                     [[NSString stringWithFormat:@"the promised reachability of %@", candidate.lastPathComponent] UTF8String],
                     [NSString stringWithFormat:@"the system answers %d, the backport answers %d",
                      (int)systemReachable, (int)ourReachable]);
    }
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        progress_state();
        number_formatter();
        url_encoding();
        promised_item();
        printf("checks=%d failures=%d divergences=%d\n", charon_checks, charon_failures, charon_divergences);
    }
    return charon_failures;
}
