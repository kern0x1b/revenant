#import <Foundation/Foundation.h>

#import "coreml-cases.h"

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSString *models = argc > 1 ? @(argv[1]) : @".agent-work/runs/coreml-predict/models";
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        coreml_run(models, ^(NSString *name, NSString *value) { records[name] = value ?: @"(nil)"; });
        NSData *json = [NSJSONSerialization dataWithJSONObject:records
                                                      options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                        error:NULL];
        [json writeToFile:@(getenv("COREML_RECORDS")) atomically:YES];
        printf("records: %lu\n", (unsigned long)records.count);
    }
    return 0;
}
