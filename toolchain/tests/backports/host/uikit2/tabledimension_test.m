#import <UIKit/UIKit.h>
#import "check.h"

extern const CGFloat CharonHostUITableViewAutomaticDimension;

int main(void)
{
    @autoreleasepool {
        charon_check(CharonHostUITableViewAutomaticDimension == UITableViewAutomaticDimension, "UITableViewAutomaticDimension has the system's value",
                     [NSString stringWithFormat:@"%g != %g", CharonHostUITableViewAutomaticDimension, UITableViewAutomaticDimension]);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures ? 1 : 0;
    }
}
