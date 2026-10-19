#import <Foundation/Foundation.h>
#import "relativedatetime-cases.h"

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableString *out = [NSMutableString stringWithString:@"static const char *const relative_expectations[] = {\n"];
        for (size_t index = 0; index < RELATIVE_CASE_COUNT; index++) {
            NSString *text = relative_answer([[NSRelativeDateTimeFormatter alloc] init], index);
            text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
            text = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            [out appendFormat:@"    \"%@\",\n", text];
        }
        [out appendString:@"};\n"];
        [out writeToFile:@(argv[1]) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return 0;
}
