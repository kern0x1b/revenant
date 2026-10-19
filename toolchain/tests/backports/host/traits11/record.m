#import <UIKit/UIKit.h>
#import "traits11-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        traits11_run(nil, ^(NSString *name, NSString *value) { records[name] = value; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("TRAITS11_RECORDS")) atomically:YES];
    }
    return 0;
}
