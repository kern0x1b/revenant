#import <Foundation/Foundation.h>
#import "orderedcollections-cases.h"

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableString *out = [NSMutableString stringWithString:@"static const uint64_t oc_expectations[] = {\n"];
        for (size_t index = 0; index < OC_CASE_COUNT; index++)
            [out appendFormat:@"    0x%016llxull,\n", (unsigned long long)oc_hash(oc_answer(index))];
        [out appendString:@"};\n"];
        [out writeToFile:@(argv[1]) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return 0;
}
