#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@implementation UITableView (CharonBatchUpdates)

- (void)performBatchUpdates:(void (NS_NOESCAPE ^)(void))updates completion:(void (^)(BOOL finished))completion
{
    [CATransaction begin];
    if (completion)
        [CATransaction setCompletionBlock:^{
            completion(YES);
        }];
    [self beginUpdates];
    if (updates)
        updates();
    [self endUpdates];
    [CATransaction commit];
}

@end
