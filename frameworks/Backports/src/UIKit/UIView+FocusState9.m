#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantRemembersFocusKey;

@implementation UITableView (RevenantFocusState9)

- (BOOL)remembersLastFocusedIndexPath
{
    return [objc_getAssociatedObject(self, &RevenantRemembersFocusKey) boolValue];
}

- (void)setRemembersLastFocusedIndexPath:(BOOL)remembersLastFocusedIndexPath
{
    objc_setAssociatedObject(self, &RevenantRemembersFocusKey, @(remembersLastFocusedIndexPath), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UICollectionView (RevenantFocusState9)

- (BOOL)remembersLastFocusedIndexPath
{
    return [objc_getAssociatedObject(self, &RevenantRemembersFocusKey) boolValue];
}

- (void)setRemembersLastFocusedIndexPath:(BOOL)remembersLastFocusedIndexPath
{
    objc_setAssociatedObject(self, &RevenantRemembersFocusKey, @(remembersLastFocusedIndexPath), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

