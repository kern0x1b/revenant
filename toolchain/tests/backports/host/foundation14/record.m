#import <Foundation/Foundation.h>
#import "foundation14-cases.h"

static NSString *escaped(NSString *text)
{
    text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    text = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    return [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableString *artifacts = [NSMutableString stringWithString:@"static const char *const f14_artifacts[] = {\n"];
        NSMutableString *expectations = [NSMutableString stringWithString:@"static const char *const f14_expectations[] = {\n"];
        for (size_t index = 0; index < F14_COUNT; index++) {
            NSString *artifact = f14_artifact(index);
            [artifacts appendFormat:@"    \"%@\",\n", artifact];
            [expectations appendFormat:@"    \"%@\",\n", escaped(f14_answer(index, artifact))];
        }
        [artifacts appendString:@"};\n"];
        [expectations appendString:@"};\n"];
        [[NSString stringWithFormat:@"%@\n%@", artifacts, expectations] writeToFile:@(argv[1]) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return 0;
}
