#import <Foundation/Foundation.h>
#import "certificate-cases.h"

// The one harness both builds run: it collects whatever the cases record into a JSON file whose path
// comes from the environment, so the same cases can be run against the host's Security framework and
// against the port's sheet in one process each, and the two compared.
int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        certificate_run(^(NSString *name, NSString *value) { records[name] = value ?: [NSNull null]; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL]
            writeToFile:@(getenv("CERTIFICATE_RECORDS")) atomically:YES];
    }
    return 0;
}
