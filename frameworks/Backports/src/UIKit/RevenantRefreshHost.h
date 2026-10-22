#import <UIKit/UIKit.h>

@interface RevenantRefreshHost : UIView

+ (void)setControl:(UIRefreshControl *)control forScrollView:(UIScrollView *)scrollView;

- (void)beginRefreshingSendingAction:(BOOL)sendAction;
- (void)endRefreshing;
- (BOOL)isRefreshing;
- (void)detach;

@end
