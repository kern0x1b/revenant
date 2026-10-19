#import <UIKit/UIKit.h>
#import "homeindicator-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        homeindicator_run(nil, ^(NSString *name, NSString *value) { records[name] = value; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("HOMEINDICATOR_RECORDS")) atomically:YES];
    }
    return 0;
}
