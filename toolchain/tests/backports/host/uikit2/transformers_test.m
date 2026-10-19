#import "transformers_scenario.h"
#import "check.h"

void charon_windowed_run(UIWindow *window)
{
    (void)window;
    @autoreleasepool {
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")]
                                                       encoding:NSUTF8StringEncoding error:NULL];
        NSArray *ours = transformers_scenario(), *theirs = [expected componentsSeparatedByString:@"\n"];
        charon_check(ours.count == theirs.count, @"the port answers every case the host answers",
                     [NSString stringWithFormat:@"%lu of %lu", (unsigned long)ours.count, (unsigned long)theirs.count]);
        NSUInteger shared = MIN(ours.count, theirs.count);
        for (NSUInteger index = 0; index < shared; index++)
            charon_check([ours[index] isEqualToString:theirs[index]],
                         @"a transformed colour is the host's own",
                         [NSString stringWithFormat:@"%@ != %@", ours[index], theirs[index]]);
        NSLog(@"info colour transformers, port against host:\n%@", [ours componentsJoinedByString:@"\n"]);
    }
}
