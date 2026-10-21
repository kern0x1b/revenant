#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UITableView (RevenantGetter15)

- (BOOL)prefetchingEnabled
{
    return [self isPrefetchingEnabled];
}

@end
