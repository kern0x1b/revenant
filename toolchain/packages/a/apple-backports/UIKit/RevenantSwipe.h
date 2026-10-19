#import <UIKit/UIKit.h>

@interface UITableViewRowAction (CharonSwipe)
- (void)charon_performForIndexPath:(NSIndexPath *)indexPath;
@end

@interface UITableView (CharonSwipe)
- (void)charon_installSwipeActions;
@end

BOOL charon_swipe_class_is_backport(Class cls);
