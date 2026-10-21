#import <UIKit/UIKit.h>

@implementation UIScreen (RevenantSnapshot7)

- (UIView *)snapshotViewAfterScreenUpdates:(BOOL)afterUpdates
{
    UIView *snapshot = [[UIView alloc] initWithFrame:self.bounds];
    NSArray *windows = [[UIApplication sharedApplication].windows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *first, UIWindow *second) {
        if (first.windowLevel == second.windowLevel)
            return NSOrderedSame;
        return first.windowLevel < second.windowLevel ? NSOrderedAscending : NSOrderedDescending;
    }];
    for (UIWindow *window in windows) {
        if (window.screen != self || window.hidden)
            continue;
        UIView *view = [window snapshotViewAfterScreenUpdates:afterUpdates];
        view.frame = window.frame;
        [snapshot addSubview:view];
    }
    return snapshot;
}

@end
