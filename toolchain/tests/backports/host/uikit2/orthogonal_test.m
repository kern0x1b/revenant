#import <UIKit/UIKit.h>
#import "check.h"
#import "compositional-cases.m"

void charon_windowed_run(UIWindow *window);

static void record_orthogonal(NSArray *answers)
{
    const char *path = getenv("CHARON_ORTHOGONAL_EXPECTATIONS");
    if (!path)
        return;
    NSMutableString *out = [NSMutableString stringWithString:@"static const char *const compositional_orthogonal_expectations[] = {\n"];
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
    NSArray *expected = compositional_orthogonal_lines(system, window, YES);
    NSArray *actual = compositional_orthogonal_lines(port, window, NO);
    CHECK(expected.count > 100 && expected.count == actual.count, "the same scripted offsets ran against the port and the system");
    BOOL all = expected.count == actual.count;
    for (NSUInteger index = 0; index < MIN(expected.count, actual.count); index++) {
        NSString *name = [NSString stringWithFormat:@"orthogonal %@", [expected[index] substringToIndex:MIN(40u, (unsigned)[expected[index] length])]];
        BOOL same = [actual[index] isEqual:expected[index]];
        all = all && same;
        charon_check(same, name.UTF8String, [NSString stringWithFormat:@"\n    port   %@\n    system %@", actual[index], expected[index]]);
    }
    if (all)
        record_orthogonal(expected);
}
