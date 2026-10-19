#import <UIKit/UIKit.h>
#import "webkit-cases.h"

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        webkit_run(container, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("%s: %s\n", name.UTF8String, value.UTF8String);
        });
        if (argc > 1)
            [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(argv[1]) atomically:YES];
    }
    return 0;
}
