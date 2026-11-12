#import <Foundation/Foundation.h>
#import "RevenantTextFieldAlignment.h"
#import "check.h"

static void expect(const char *name, long current, long expected)
{
    long seen = RevenantTextFieldInitialAlignment(current);
    revenant_check(seen == expected, name, [NSString stringWithFormat:@"%ld is not %ld", seen, expected]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        expect("the top default becomes center", 1, revenant_negative ? 1 : 0);
        expect("center stays", 0, 0);
        expect("bottom is the application's", 2, 2);
        expect("fill is the application's", 3, 3);
    }
    return revenant_finish();
}
