#import <UIKit/UIKit.h>

// The focus update context of a table view: the two index paths of one focus move in it. It has no focus engine
// behind it on iOS 6, and it is made the way its superclass is, so init raises as the superclass's does. An allocated
// one answers nil for both paths, as the host does.
@implementation UITableViewFocusUpdateContext

- (NSIndexPath *)previouslyFocusedIndexPath
{
    return nil;
}

- (NSIndexPath *)nextFocusedIndexPath
{
    return nil;
}

@end
