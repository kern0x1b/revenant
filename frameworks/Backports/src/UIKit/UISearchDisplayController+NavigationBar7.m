#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantDisplaysInBarKey;
static const char RevenantPreviousTitleViewKey;

@implementation UISearchDisplayController (RevenantNavigationBar7)

- (BOOL)displaysSearchBarInNavigationBar
{
    return [objc_getAssociatedObject(self, &RevenantDisplaysInBarKey) boolValue];
}

- (void)setDisplaysSearchBarInNavigationBar:(BOOL)displaysSearchBarInNavigationBar
{
    if (displaysSearchBarInNavigationBar == self.displaysSearchBarInNavigationBar)
        return;
    UINavigationItem *item = self.searchContentsController.navigationItem;
    if (displaysSearchBarInNavigationBar) {
        objc_setAssociatedObject(self, &RevenantPreviousTitleViewKey, item.titleView ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        item.titleView = self.searchBar;
    } else {
        id previous = objc_getAssociatedObject(self, &RevenantPreviousTitleViewKey);
        if (item.titleView == self.searchBar)
            item.titleView = previous == [NSNull null] ? nil : previous;
        objc_setAssociatedObject(self, &RevenantPreviousTitleViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    objc_setAssociatedObject(self, &RevenantDisplaysInBarKey, @(displaysSearchBarInNavigationBar), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UINavigationItem *)navigationItem
{
    return self.displaysSearchBarInNavigationBar ? self.searchContentsController.navigationItem : nil;
}

@end
