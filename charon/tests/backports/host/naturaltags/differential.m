#import <Foundation/Foundation.h>
#import <NaturalLanguage/NaturalLanguage.h>
#import <dlfcn.h>
#import <objc/runtime.h>

// The value behind each of NaturalLanguage's 71 string constants the port carries, against the host's
// own NaturalLanguage.
//
// The host is the oracle and nothing else is. These constants are `NSString * const` in every SDK
// header and no header states a value: NLTagScheme.h, NLScript.h and NLLanguage.h declare the name and
// the release it arrived in and nothing else, so a value read out of the header would be an
// invention. Each one is a data symbol in the framework, so dlsym reaches it and the host's own
// framework answers with the string the system's tagger, script table and language table use.
//
// This run is what wrote the table the port's own definitions came from
// (values.tsv, beside this file), and it is re-run against that table so a value that moved, or a
// constant the port spells wrongly, is caught.
//
// It also checks that each constant really is a string, and it reports which names share a value.
// NLTagScheme.h says a tag is used with == comparison, so two names with one value are two spellings
// of one tag -- and the host has two such pairs, which is Apple's own answer and the reason this
// reports them instead of refusing them: NLTagOtherPunctuation is the string NLTagPunctuation is, and
// NLTagOtherWhitespace is the string NLTagWhitespace is.

static int different = 0;
static long checks = 0;

static NSString *host_value(NSString *name)
{
    void *symbol = dlsym(RTLD_DEFAULT, name.UTF8String);
    if (!symbol)
        return nil;
    return *(__unsafe_unretained NSString **)symbol;
}

static void read_names(NSString *path, NSMutableArray<NSString *> *introduced,
                       NSMutableArray<NSString *> *names)
{
    NSString *table = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    for (NSString *line in [table componentsSeparatedByString:@"\n"]) {
        if (!line.length)
            continue;
        NSArray<NSString *> *columns = [line componentsSeparatedByString:@"\t"];
        [introduced addObject:columns[0]];
        [names addObject:columns[1]];
    }
}

static void report_collisions(NSArray<NSString *> *names, NSArray<NSString *> *prefixes, const char *what)
{
    NSMutableDictionary<NSString *, NSString *> *seen = [NSMutableDictionary dictionary];
    NSUInteger in_group = 0, colliding = 0;
    for (NSString *name in names) {
        BOOL belongs = NO;
        for (NSString *prefix in prefixes)
            belongs = belongs || [name hasPrefix:prefix];
        if (!belongs)
            continue;
        in_group++;
        NSString *value = host_value(name);
        NSString *other = seen[value];
        if (other) {
            colliding++;
            printf("naturaltags: %s names sharing one value: %s and %s are both %s\n", what,
                   other.UTF8String, name.UTF8String, value.UTF8String);
        } else {
            seen[value] = name;
        }
    }
    printf("naturaltags: %lu %s constants, %lu distinct values, %lu names sharing a value\n",
           (unsigned long)in_group, what, (unsigned long)seen.count, (unsigned long)colliding);
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        NSString *here = [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@"names.tsv"];
        NSString *values = [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@"values.tsv"];

        NSMutableArray<NSString *> *introduced = [NSMutableArray array], *names = [NSMutableArray array];
        read_names(here, introduced, names);

        BOOL measure = argc > 1 && strcmp(argv[1], "--measure") == 0;
        NSMutableDictionary<NSString *, NSString *> *measured = [NSMutableDictionary dictionary];
        for (NSString *name in names) {
            checks++;
            NSString *value = host_value(name);
            if (!value) {
                different++;
                printf("%s: the host exports no such symbol\n", name.UTF8String);
                continue;
            }
            if (![value isKindOfClass:[NSString class]]) {
                different++;
                printf("%s: the host's is a %s, not a string\n", name.UTF8String,
                       class_getName([value class]));
                continue;
            }
            measured[name] = value;
        }

        if (measure) {
            NSMutableString *out = [NSMutableString string];
            for (NSString *name in names)
                [out appendFormat:@"%@\t%@\n", name, measured[name]];
            [out writeToFile:values atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            printf("naturaltags: wrote %lu measured values to values.tsv\n", (unsigned long)measured.count);
        } else {
            NSString *table = [NSString stringWithContentsOfFile:values encoding:NSUTF8StringEncoding error:NULL];
            NSMutableDictionary<NSString *, NSString *> *expected = [NSMutableDictionary dictionary];
            for (NSString *line in [table componentsSeparatedByString:@"\n"]) {
                if (!line.length)
                    continue;
                NSArray<NSString *> *pair = [line componentsSeparatedByString:@"\t"];
                expected[pair[0]] = pair[1];
            }
            long compared = 0;
            for (NSString *name in names) {
                checks++;
                NSString *want = expected[name];
                NSString *got = measured[name];
                if (!want) {
                    different++;
                    printf("%s: values.tsv has no row for it\n", name.UTF8String);
                } else if (![want isEqualToString:got]) {
                    different++;
                    printf("%s: values.tsv says %s, the host says %s\n", name.UTF8String,
                           want.UTF8String, got.UTF8String);
                } else {
                    compared++;
                }
            }
            printf("naturaltags: %ld values compared against the host's own NaturalLanguage\n", compared);
        }

        report_collisions(names, @[@"NLTag"], "tag");
        report_collisions(names, @[@"NLScript"], "script");
        report_collisions(names, @[@"NLLanguage"], "language");

        printf("naturaltags: %ld checks, %d different\n", checks, different);
        return different ? 1 : 0;
    }
}