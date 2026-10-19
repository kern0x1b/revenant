#import <Foundation/Foundation.h>
#import "datecomponents-cases.h"

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableString *out = [NSMutableString stringWithString:@"static const char *const date_components_expectations[] = {\n"];
        for (size_t index = 0; index < DATE_COMPONENTS_CASE_COUNT; index++) {
            NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
            NSString *text = date_components_answer(formatter, &date_components_cases[index]);
            text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
            text = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            [out appendFormat:@"    \"%@\",\n", text];
        }
        [out appendString:@"};\n"];
        [out writeToFile:@(argv[1]) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return 0;
}
