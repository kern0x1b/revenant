#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *RevenantSearchControllerKey = &RevenantSearchControllerKey;
static const void *RevenantHidesSearchBarKey = &RevenantHidesSearchBarKey;

@interface UISearchController (RevenantNavigationItem)
- (void)revenant_setNavigationItem:(UINavigationItem *)item;
@end

@implementation UINavigationItem (RevenantSearchController)

- (UISearchController *)searchController
{
    return objc_getAssociatedObject(self, RevenantSearchControllerKey);
}

- (void)setSearchController:(UISearchController *)searchController
{
    UISearchController *previous = self.searchController;
    if (previous == searchController)
        return;
    if (previous && self.titleView == previous.searchBar)
        self.titleView = nil;
    [previous revenant_setNavigationItem:nil];
    objc_setAssociatedObject(self, RevenantSearchControllerKey, searchController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (searchController) {
        [searchController revenant_setNavigationItem:self];
        UISearchBar *bar = searchController.searchBar;
        [bar sizeToFit];
        self.titleView = bar;
    }
}

- (BOOL)hidesSearchBarWhenScrolling
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantHidesSearchBarKey);
    return value ? value.boolValue : YES;
}

- (void)setHidesSearchBarWhenScrolling:(BOOL)hides
{
    objc_setAssociatedObject(self, RevenantHidesSearchBarKey, @(hides), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
