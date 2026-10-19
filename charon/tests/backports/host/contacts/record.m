#import <Foundation/Foundation.h>
#import "contacts-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        contacts_run(^(NSString *name, NSString *value) { records[name] = value ?: [NSNull null]; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("CONTACTS_RECORDS")) atomically:YES];
    }
    return 0;
}
