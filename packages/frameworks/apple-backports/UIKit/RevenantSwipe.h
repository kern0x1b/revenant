#import <UIKit/UIKit.h>

@interface UITableViewRowAction (RevenantSwipe)
- (void)revenant_performForIndexPath:(NSIndexPath *)indexPath;
@end

@interface UITableView (RevenantSwipe)
- (void)revenant_installSwipeActions;
@end

BOOL revenant_swipe_class_is_backport(Class cls);
