#import <Foundation/Foundation.h>
#import "uikitconst-cases.h"

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        void (^keep)(NSString *, NSString *) = ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("%s: %s\n", name.UTF8String, value.UTF8String);
        };
        uikitconst_run(keep);
        uikitrotor_run(keep);
        if (argc > 1)
            [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(argv[1]) atomically:YES];
    }
    return 0;
}
