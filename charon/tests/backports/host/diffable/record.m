#import <UIKit/UIKit.h>
#import "diffable-cases.h"

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableString *out = [NSMutableString stringWithString:@"static const uint64_t df_expectations[] = {\n"];
        for (size_t index = 0; index < DIFFABLE_CASE_COUNT; index++)
            [out appendFormat:@"    0x%016llxull,\n", (unsigned long long)df_hash(df_answer(index))];
        [out appendString:@"};\n"];
        [out writeToFile:@(argv[1]) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return 0;
}
