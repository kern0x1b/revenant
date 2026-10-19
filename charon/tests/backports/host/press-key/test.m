#import <UIKit/UIKit.h>
#include <stdio.h>

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        report("press-responds-key", yes_no([UIPress instancesRespondToSelector:@selector(key)]));
        UIPress *press = [[UIPress alloc] init];
        report("press-key-of-fresh", press.key ? @"set" : @"nil");
        report("press-key-of-fresh-type", [NSString stringWithFormat:@"%ld", (long)press.type]);
    }
    return 0;
}
