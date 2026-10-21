#import <UIKit/UIKit.h>

@implementation UISearchContainerViewController {
    UISearchController *_searchController;
}

- (instancetype)initWithSearchController:(UISearchController *)searchController
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _searchController = searchController;
        [self addChildViewController:searchController];
        [searchController didMoveToParentViewController:self];
    }
    return self;
}

- (UISearchController *)searchController
{
    return _searchController;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIView *searchView = _searchController.view;
    searchView.frame = self.view.bounds;
    searchView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:searchView];
}

@end
