#import <UIKit/UIKit.h>
#import "check.h"
#import "compositional-cases.m"

void charon_windowed_run(UIWindow *window);

static void record_sized(NSArray *answers)
{
    const char *path = getenv("CHARON_SIZED_EXPECTATIONS");
    if (!path)
        return;
    NSMutableString *out = [NSMutableString stringWithString:@"static const char *const compositional_sized_expectations[] = {\n"];
    for (NSString *answer in answers) {
        NSString *text = [answer stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        text = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        [out appendFormat:@"    \"%@\",\n", text];
    }
    [out appendString:@"};\n"];
    [out writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

void charon_windowed_run(UIWindow *window)
{
    CompositionalKit system = compositional_kit(@""), port = compositional_kit(@"CharonHost");
    NSMutableArray *answers = [NSMutableArray array];
    BOOL all = YES;
    for (NSUInteger index = 0; index < compositional_sized_count(); index++) {
        NSString *expected = compositional_sized_dump(system, index, window);
        NSString *actual = compositional_sized_dump(port, index, window);
        [answers addObject:expected];
        BOOL same = [actual isEqual:expected];
        all = all && same;
        NSString *name = [NSString stringWithFormat:@"sized %@", compositional_sized_name(index)];
        charon_check(same, name.UTF8String, same ? @"" : [NSString stringWithFormat:@"\n  port\n%@\n  system\n%@", actual, expected]);
    }
    charon_check(compositional_release_while_pending(port, window), "a layout and a data source released while a measurement is waiting are not touched", @"");
    if (all)
        record_sized(answers);
}
