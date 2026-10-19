#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *CharonSearchControllerKey = &CharonSearchControllerKey;
static const void *CharonHidesSearchBarKey = &CharonHidesSearchBarKey;

@interface UISearchController (CharonNavigationItem)
- (void)charon_setNavigationItem:(UINavigationItem *)item;
@end

@implementation UINavigationItem (CharonSearchController)

- (UISearchController *)searchController
{
    return objc_getAssociatedObject(self, CharonSearchControllerKey);
}

- (void)setSearchController:(UISearchController *)searchController
{
    UISearchController *previous = self.searchController;
    if (previous == searchController)
        return;
    if (previous && self.titleView == previous.searchBar)
        self.titleView = nil;
    [previous charon_setNavigationItem:nil];
    objc_setAssociatedObject(self, CharonSearchControllerKey, searchController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (searchController) {
        [searchController charon_setNavigationItem:self];
        UISearchBar *bar = searchController.searchBar;
        [bar sizeToFit];
        self.titleView = bar;
    }
}

- (BOOL)hidesSearchBarWhenScrolling
{
    NSNumber *value = objc_getAssociatedObject(self, CharonHidesSearchBarKey);
    return value ? value.boolValue : YES;
}

- (void)setHidesSearchBarWhenScrolling:(BOOL)hides
{
    objc_setAssociatedObject(self, CharonHidesSearchBarKey, @(hides), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
