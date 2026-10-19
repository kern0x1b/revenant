#import <UIKit/UIKit.h>
#include <stdio.h>

// UIPress.key, checked on the same values in two processes: the host's class in one, and the port's (renamed by run.sh) in the other. Each
// line is "check<TAB>value"; the two outputs must match line for line. A press from a touch has no key, and the port makes no press from a
// hardware keyboard, so the key of a press it makes is nil; the host's presses made here are the same kind.

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
