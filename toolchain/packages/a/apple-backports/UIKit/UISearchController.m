#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const CGFloat revenant_dimming_alpha = 0.15f;
static const NSTimeInterval revenant_presentation_duration = 0.3;
static char revenant_placeholder_key;

@interface RevenantSearchBar : UISearchBar
- (void)revenant_attachController:(id<UISearchBarDelegate>)controller;
@end

@implementation RevenantSearchBar {
    __weak id<UISearchBarDelegate> _controller;
    __weak id<UISearchBarDelegate> _applicationDelegate;
}

- (NSString *)text
{
    return [super text] ?: @"";
}

- (void)revenant_attachController:(id<UISearchBarDelegate>)controller
{
    _controller = controller;
    [super setDelegate:controller];
}

- (void)setDelegate:(id<UISearchBarDelegate>)delegate
{
    _applicationDelegate = delegate;
    [super setDelegate:_controller];
}

- (id<UISearchBarDelegate>)delegate
{
    return _applicationDelegate;
}

@end

@interface UISearchController () <UISearchBarDelegate>
@end

@implementation UISearchController {
    UIViewController *_resultsController;
    RevenantSearchBar *_searchBar;
    __weak id<UISearchResultsUpdating> _searchResultsUpdater;
    __weak id<UISearchControllerDelegate> _delegate;
    BOOL _obscuresBackgroundDuringPresentation;
    BOOL _hidesNavigationBarDuringPresentation;
    BOOL _presented;
    BOOL _dismissing;
    __weak UIViewController *_host;
    UIView *_dimmingView;
    UIView *_barContainer;
    UIView *_resultsContainer;
    __weak UIView *_originalSuperview;
    NSUInteger _originalIndex;
    CGRect _originalFrame;
    UIViewAutoresizing _originalMask;
    BOOL _originalShowsCancel;
    BOOL _hidNavigationBar;
    BOOL _automaticallyShowsCancelButton;
    BOOL _automaticallyShowsSearchResultsController;
    BOOL _showsSearchResultsController;
    __weak UINavigationItem *_navigationItem;
    UISearchControllerScopeBarActivation _scopeBarActivation;
    BOOL _ignoresSearchSuggestionsForSearchBarPlacementStacked;
}

@dynamic automaticallyShowsScopeBar;
@synthesize searchResultsUpdater = _searchResultsUpdater, delegate = _delegate, searchResultsController = _resultsController, searchBar = _searchBar;
@synthesize obscuresBackgroundDuringPresentation = _obscuresBackgroundDuringPresentation;
@synthesize hidesNavigationBarDuringPresentation = _hidesNavigationBarDuringPresentation;

- (instancetype)initWithSearchResultsController:(UIViewController *)searchResultsController
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _resultsController = searchResultsController;
        [self revenant_commonInit];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
        [self revenant_commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _resultsController = [coder decodeObjectForKey:@"UISearchControllerResultsController"];
        [self revenant_commonInit];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_resultsController forKey:@"UISearchControllerResultsController"];
}

- (void)revenant_commonInit
{
    _obscuresBackgroundDuringPresentation = YES;
    _hidesNavigationBarDuringPresentation = YES;
    _automaticallyShowsCancelButton = YES;
    _automaticallyShowsSearchResultsController = YES;
    _scopeBarActivation = UISearchControllerScopeBarActivationManual;
    _searchBar = [[RevenantSearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    _searchBar.placeholder = NSLocalizedStringFromTableInBundle(@"Search", @"Localizable", [NSBundle bundleForClass:[UIView class]], nil);
    [_searchBar revenant_attachController:self];
}

- (void)revenant_setNavigationItem:(UINavigationItem *)item
{
    _navigationItem = item;
}

- (UINavigationItemSearchBarPlacement)searchBarPlacement
{
    if (!_navigationItem)
        return UINavigationItemSearchBarPlacementStacked;
    return _navigationItem.preferredSearchBarPlacement == UINavigationItemSearchBarPlacementStacked ? UINavigationItemSearchBarPlacementStacked
                                                                                                       : UINavigationItemSearchBarPlacementInline;
}

- (NSArray *)searchSuggestions
{
    return @[];
}

- (void)setSearchSuggestions:(NSArray *)suggestions
{
    (void)suggestions;
}

- (UISearchControllerScopeBarActivation)scopeBarActivation
{
    return _scopeBarActivation;
}

- (void)setScopeBarActivation:(UISearchControllerScopeBarActivation)activation
{
    _scopeBarActivation = activation;
}

- (BOOL)ignoresSearchSuggestionsForSearchBarPlacementStacked
{
    return _ignoresSearchSuggestionsForSearchBarPlacementStacked;
}

- (void)setIgnoresSearchSuggestionsForSearchBarPlacementStacked:(BOOL)ignores
{
    _ignoresSearchSuggestionsForSearchBarPlacementStacked = ignores;
}

- (BOOL)dimsBackgroundDuringPresentation
{
    return _obscuresBackgroundDuringPresentation;
}

- (void)setDimsBackgroundDuringPresentation:(BOOL)dims
{
    _obscuresBackgroundDuringPresentation = dims;
}

- (BOOL)isActive
{
    if (_dismissing)
        return NO;
    if (_presented)
        return YES;
    return self.presentingViewController != nil && ![self isBeingDismissed];
}

- (void)setActive:(BOOL)active
{
    if (active)
        [self revenant_present];
    else
        [self revenant_dismiss];
}

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = [UIColor clearColor];
    self.view = view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIView *view = self.view;
    _dimmingView = [[UIView alloc] initWithFrame:view.bounds];
    _dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _dimmingView.backgroundColor = [UIColor colorWithWhite:0 alpha:revenant_dimming_alpha];
    [_dimmingView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_dimmingViewTapped:)]];
    [view addSubview:_dimmingView];
    _resultsContainer = [[UIView alloc] initWithFrame:view.bounds];
    _resultsContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _resultsContainer.hidden = YES;
    [view addSubview:_resultsContainer];
    if (_resultsController) {
        [self addChildViewController:_resultsController];
        _resultsController.view.frame = _resultsContainer.bounds;
        _resultsController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_resultsContainer addSubview:_resultsController.view];
        [_resultsController didMoveToParentViewController:self];
    }
    _barContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, view.bounds.size.width, 44)];
    _barContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [view addSubview:_barContainer];
}

- (void)revenant_dimmingViewTapped:(UITapGestureRecognizer *)recognizer
{
    [self revenant_dismiss];
}

- (UIViewController *)revenant_locatePresenter
{
    UIResponder *responder = _searchBar;
    while (responder && ![responder isKindOfClass:[UIViewController class]])
        responder = [responder nextResponder];
    UIViewController *found = (UIViewController *)responder;
    if (!found) {
        UIWindow *window = _searchBar.window ?: [UIApplication sharedApplication].keyWindow;
        found = window.rootViewController;
    }
    for (UIViewController *candidate = found; candidate; candidate = candidate.parentViewController) {
        if (candidate.definesPresentationContext)
            return candidate;
    }
    return found;
}

- (CGFloat)revenant_statusBarInsetForHost:(UIViewController *)host
{
    UIApplication *application = [UIApplication sharedApplication];
    if (application.statusBarHidden)
        return 0;
    CGRect onScreen = [host.view convertRect:host.view.bounds toView:nil];
    return MAX(0, CGRectGetHeight(application.statusBarFrame) - MAX(0, CGRectGetMinY(onScreen)));
}

- (void)revenant_layoutBarContainer
{
    UIViewController *host = _host;
    if (!host)
        return;
    CGFloat inset = [self revenant_statusBarInsetForHost:host];
    CGFloat height = _searchBar.bounds.size.height;
    _barContainer.frame = CGRectMake(0, 0, self.view.bounds.size.width, inset + height);
    _searchBar.frame = CGRectMake(0, inset, _barContainer.bounds.size.width, height);
    CGRect results = self.view.bounds;
    results.origin.y = CGRectGetMaxY(_barContainer.frame);
    results.size.height -= results.origin.y;
    _resultsContainer.frame = results;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (_presented)
        [self revenant_layoutBarContainer];
}

- (void)revenant_updateVisibility
{
    _resultsContainer.hidden = _automaticallyShowsSearchResultsController ? _searchBar.text.length == 0 : !_showsSearchResultsController;
}

- (BOOL)automaticallyShowsCancelButton
{
    return _automaticallyShowsCancelButton;
}

- (void)setAutomaticallyShowsCancelButton:(BOOL)shows
{
    _automaticallyShowsCancelButton = shows;
}

- (BOOL)automaticallyShowsSearchResultsController
{
    return _automaticallyShowsSearchResultsController;
}

- (void)setAutomaticallyShowsSearchResultsController:(BOOL)shows
{
    _automaticallyShowsSearchResultsController = shows;
    if (_resultsContainer)
        [self revenant_updateVisibility];
}

- (BOOL)showsSearchResultsController
{
    return _resultsContainer ? !_resultsContainer.hidden : _showsSearchResultsController;
}

- (void)setShowsSearchResultsController:(BOOL)shows
{
    _showsSearchResultsController = shows;
    _automaticallyShowsSearchResultsController = NO;
    if (_resultsContainer)
        [self revenant_updateVisibility];
}

- (void)revenant_updateResults
{
    id<UISearchResultsUpdating> updater = _searchResultsUpdater;
    if (updater)
        [updater updateSearchResultsForSearchController:self];
}

- (void)revenant_present
{
    if (_presented || _dismissing)
        return;
    UIViewController *host = [self revenant_locatePresenter];
    if (!host || !host.view)
        return;
    id<UISearchControllerDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(presentSearchController:)]) {
        [delegate presentSearchController:self];
        [self revenant_updateVisibility];
        [self revenant_updateResults];
        return;
    }
    if ([delegate respondsToSelector:@selector(willPresentSearchController:)])
        [delegate willPresentSearchController:self];
    _host = host;
    _presented = YES;
    BOOL animated = [UIView areAnimationsEnabled];
    [self view];
    _originalSuperview = _searchBar.superview;
    _originalIndex = _originalSuperview ? [_originalSuperview.subviews indexOfObjectIdenticalTo:_searchBar] : 0;
    _originalFrame = _searchBar.frame;
    _originalMask = _searchBar.autoresizingMask;
    _originalShowsCancel = _searchBar.showsCancelButton;
    UIView *placeholder = nil;
    if (_originalSuperview) {
        placeholder = [[UIView alloc] initWithFrame:_originalFrame];
        placeholder.autoresizingMask = _originalMask;
        placeholder.userInteractionEnabled = NO;
        [_originalSuperview insertSubview:placeholder atIndex:_originalIndex];
        objc_setAssociatedObject(_searchBar, &revenant_placeholder_key, placeholder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [_searchBar removeFromSuperview];
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_barContainer addSubview:_searchBar];
    _dimmingView.hidden = !_obscuresBackgroundDuringPresentation;
    self.view.frame = host.view.bounds;
    self.view.alpha = animated ? 0 : 1;
    [host addChildViewController:self];
    [host.view addSubview:self.view];
    [self didMoveToParentViewController:host];
    UINavigationController *navigation = host.navigationController;
    if (_hidesNavigationBarDuringPresentation && navigation && !navigation.navigationBarHidden) {
        _hidNavigationBar = YES;
        [navigation setNavigationBarHidden:YES animated:animated];
    }
    self.view.frame = host.view.bounds;
    [self revenant_layoutBarContainer];
    if (_automaticallyShowsCancelButton)
        [_searchBar setShowsCancelButton:YES animated:animated];
    [self revenant_updateVisibility];
    void (^finish)(BOOL) = ^(BOOL finished) {
        id<UISearchControllerDelegate> current = self->_delegate;
        if ([current respondsToSelector:@selector(didPresentSearchController:)])
            [current didPresentSearchController:self];
    };
    if (animated)
        [UIView animateWithDuration:revenant_presentation_duration animations:^{ self.view.alpha = 1; } completion:finish];
    else
        finish(YES);
    [self revenant_updateResults];
}

- (void)revenant_dismissModal
{
    id<UISearchControllerDelegate> delegate = _delegate;
    _dismissing = YES;
    if ([delegate respondsToSelector:@selector(willDismissSearchController:)])
        [delegate willDismissSearchController:self];
    _searchBar.text = nil;
    [self revenant_updateResults];
    [_searchBar resignFirstResponder];
    [self.presentingViewController dismissViewControllerAnimated:[UIView areAnimationsEnabled] completion:^{
        self->_dismissing = NO;
        id<UISearchControllerDelegate> current = self->_delegate;
        if ([current respondsToSelector:@selector(didDismissSearchController:)])
            [current didDismissSearchController:self];
    }];
}

- (void)revenant_dismiss
{
    if (!_presented && [self isActive]) {
        [self revenant_dismissModal];
        return;
    }
    if (!_presented || _dismissing)
        return;
    id<UISearchControllerDelegate> delegate = _delegate;
    _dismissing = YES;
    if ([delegate respondsToSelector:@selector(willDismissSearchController:)])
        [delegate willDismissSearchController:self];
    BOOL animated = [UIView areAnimationsEnabled];
    _searchBar.text = nil;
    [self revenant_updateVisibility];
    [self revenant_updateResults];
    [_searchBar resignFirstResponder];
    UIViewController *host = _host;
    UINavigationController *navigation = host.navigationController;
    if (_hidNavigationBar) {
        _hidNavigationBar = NO;
        [navigation setNavigationBarHidden:NO animated:animated];
    }
    [_searchBar setShowsCancelButton:_originalShowsCancel animated:animated];
    void (^finish)(BOOL) = ^(BOOL finished) {
        [self revenant_restoreSearchBar];
        [self willMoveToParentViewController:nil];
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
        self->_presented = NO;
        self->_dismissing = NO;
        self->_host = nil;
        id<UISearchControllerDelegate> current = self->_delegate;
        if ([current respondsToSelector:@selector(didDismissSearchController:)])
            [current didDismissSearchController:self];
    };
    if (animated)
        [UIView animateWithDuration:revenant_presentation_duration animations:^{ self.view.alpha = 0; } completion:finish];
    else
        finish(YES);
}

- (void)revenant_restoreSearchBar
{
    UIView *placeholder = objc_getAssociatedObject(_searchBar, &revenant_placeholder_key);
    [_searchBar removeFromSuperview];
    _searchBar.autoresizingMask = _originalMask;
    _searchBar.frame = _originalFrame;
    UIView *superview = placeholder.superview ?: _originalSuperview;
    if (superview) {
        NSUInteger index = placeholder ? [superview.subviews indexOfObjectIdenticalTo:placeholder] : _originalIndex;
        [superview insertSubview:_searchBar atIndex:MIN(index, superview.subviews.count)];
    }
    [placeholder removeFromSuperview];
    objc_setAssociatedObject(_searchBar, &revenant_placeholder_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    _originalSuperview = nil;
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || [_searchBar.delegate respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector
{
    id<UISearchBarDelegate> target = _searchBar.delegate;
    return [target respondsToSelector:selector] ? target : [super forwardingTargetForSelector:selector];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    id<UISearchBarDelegate> target = searchBar.delegate;
    if ([target respondsToSelector:_cmd])
        [target searchBarTextDidBeginEditing:searchBar];
    if (_presented && !_dismissing)
        [self revenant_updateResults];
    else
        [self revenant_present];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    id<UISearchBarDelegate> target = searchBar.delegate;
    if ([target respondsToSelector:_cmd])
        [target searchBar:searchBar textDidChange:searchText];
    [self revenant_updateVisibility];
    [self revenant_updateResults];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    id<UISearchBarDelegate> target = searchBar.delegate;
    if ([target respondsToSelector:_cmd])
        [target searchBarSearchButtonClicked:searchBar];
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    id<UISearchBarDelegate> target = searchBar.delegate;
    if ([target respondsToSelector:_cmd])
        [target searchBarCancelButtonClicked:searchBar];
    [self revenant_dismiss];
}

@end
