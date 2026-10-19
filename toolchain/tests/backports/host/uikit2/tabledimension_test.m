#import <UIKit/UIKit.h>
#import "check.h"

extern const CGFloat RevenantHostUITableViewAutomaticDimension;

int main(void)
{
    @autoreleasepool {
        revenant_check(RevenantHostUITableViewAutomaticDimension == UITableViewAutomaticDimension, "UITableViewAutomaticDimension has the system's value",
                     [NSString stringWithFormat:@"%g != %g", RevenantHostUITableViewAutomaticDimension, UITableViewAutomaticDimension]);
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures ? 1 : 0;
    }
}
