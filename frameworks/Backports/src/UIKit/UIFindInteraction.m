#import <UIKit/UIKit.h>

@interface UIFindSession (RevenantFindNavigation)
- (void)revenant_clearHighlight;
@end

@interface RevenantFindNavigator : UIView
@end

@implementation RevenantFindNavigator

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), height = CGRectGetHeight(self.bounds);
    UIView *field = [self viewWithTag:1], *count = [self viewWithTag:2];
    UIView *previous = [self viewWithTag:3], *next = [self viewWithTag:4], *done = [self viewWithTag:5];
    done.frame = CGRectMake(width - 64, 0, 60, height);
    next.frame = CGRectMake(CGRectGetMinX(done.frame) - 40, 0, 40, height);
    previous.frame = CGRectMake(CGRectGetMinX(next.frame) - 40, 0, 40, height);
    count.frame = CGRectMake(CGRectGetMinX(previous.frame) - 90, 0, 90, height);
    field.frame = CGRectMake(6, 7, MAX(0, CGRectGetMinX(count.frame) - 12), height - 14);
}

@end

@implementation UIFindInteraction {
@private
    __weak id<UIFindInteractionDelegate> _delegate;
    __weak UIView *_view;
    NSString *_searchText;
    NSString *_replacementText;
    UIMenu *(^_optionsMenuProvider)(NSArray<UIMenuElement *> *defaultOptions);
    UIFindSession *_activeFindSession;
    BOOL _findNavigatorVisible;
    RevenantFindNavigator *_navigator;
    UITextField *_field;
    UILabel *_count;
    UIButton *_previous;
    UIButton *_next;
}

- (instancetype)initWithSessionDelegate:(id<UIFindInteractionDelegate>)sessionDelegate
{
    if ((self = [super init]))
        _delegate = sessionDelegate;
    return self;
}

- (id<UIFindInteractionDelegate>)delegate
{
    return _delegate;
}

- (UIView *)view
{
    return _view;
}

- (BOOL)isFindNavigatorVisible
{
    return _findNavigatorVisible;
}

- (UIFindSession *)activeFindSession
{
    return _activeFindSession;
}

- (NSString *)searchText
{
    return _searchText;
}

- (void)setSearchText:(NSString *)searchText
{
    _searchText = [searchText copy];
    if (_findNavigatorVisible) {
        _field.text = _searchText;
        [self revenant_search];
    }
}

- (NSString *)replacementText
{
    return _replacementText;
}

- (void)setReplacementText:(NSString *)replacementText
{
    _replacementText = replacementText;
}

- (UIMenu *(^)(NSArray<UIMenuElement *> *))optionsMenuProvider
{
    return _optionsMenuProvider;
}

- (void)setOptionsMenuProvider:(UIMenu *(^)(NSArray<UIMenuElement *> *))optionsMenuProvider
{
    _optionsMenuProvider = [optionsMenuProvider copy];
}

- (void)willMoveToView:(UIView *)view
{
}

- (void)didMoveToView:(UIView *)view
{
    _view = view;
}

- (void)presentFindNavigatorShowingReplace:(BOOL)showingReplace
{
    if (!_view)
        return;
    UIFindSession *session = _activeFindSession;
    if (!session && [_delegate respondsToSelector:@selector(findInteraction:sessionForView:)])
        session = [_delegate findInteraction:self sessionForView:_view];
    if (!session && [_view isKindOfClass:[UITextView class]])
        session = [[UITextSearchingFindSession alloc] initWithSearchableObject:(id<UITextSearching>)_view];
    if (!session)
        return;
    _activeFindSession = session;
    _findNavigatorVisible = YES;
    [self revenant_showNavigator];
    if ([_delegate respondsToSelector:@selector(findInteraction:didBeginFindSession:)])
        [_delegate findInteraction:self didBeginFindSession:session];
}

- (void)dismissFindNavigator
{
    if (!_findNavigatorVisible)
        return;
    _findNavigatorVisible = NO;
    UIFindSession *session = _activeFindSession;
    [_field resignFirstResponder];
    [_navigator removeFromSuperview];
    [session revenant_clearHighlight];
    if ([_delegate respondsToSelector:@selector(findInteraction:didEndFindSession:)])
        [_delegate findInteraction:self didEndFindSession:session];
    _activeFindSession = nil;
}

- (void)findNext
{
    [self revenant_moveInDirection:UITextStorageDirectionForward];
}

- (void)findPrevious
{
    [self revenant_moveInDirection:UITextStorageDirectionBackward];
}

- (void)updateResultCount
{
    UIFindSession *session = _activeFindSession;
    NSInteger total = session.resultCount;
    NSInteger index = session.highlightedResultIndex;
    NSString *text = @"";
    switch (session.searchResultDisplayStyle) {
        case UIFindSessionSearchResultDisplayStyleCurrentAndTotal:
            text = total ? [NSString stringWithFormat:@"%ld of %ld", (long)(index + 1), (long)total] : @"No results";
            break;
        case UIFindSessionSearchResultDisplayStyleTotal:
            text = total == 1 ? @"1 result" : total ? [NSString stringWithFormat:@"%ld results", (long)total] : @"No results";
            break;
        case UIFindSessionSearchResultDisplayStyleNone:
            break;
    }
    _count.text = text;
    _previous.enabled = total > 0;
    _next.enabled = total > 0;
}

- (void)revenant_moveInDirection:(UITextStorageDirection)direction
{
    if (!_findNavigatorVisible || !_activeFindSession)
        return;
    [_activeFindSession highlightNextResultInDirection:direction];
    [self updateResultCount];
}

- (void)revenant_search
{
    UIFindSession *session = _activeFindSession;
    if (!session)
        return;
    [session performSearchWithQuery:_searchText options:nil];
    [self updateResultCount];
}

- (void)revenant_searchFieldChanged
{
    _searchText = [_field.text copy];
    [self revenant_search];
}

- (void)revenant_showNavigator
{
    if (!_navigator)
        [self revenant_buildNavigator];
    _field.text = _searchText;
    _navigator.frame = CGRectMake(0, CGRectGetHeight(_view.bounds) - 44, CGRectGetWidth(_view.bounds), 44);
    _navigator.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_view addSubview:_navigator];
    [self revenant_search];
}

- (void)revenant_buildNavigator
{
    _navigator = [[RevenantFindNavigator alloc] initWithFrame:CGRectZero];
    _navigator.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1];

    _field = [[UITextField alloc] initWithFrame:CGRectZero];
    _field.tag = 1;
    _field.borderStyle = UITextBorderStyleRoundedRect;
    _field.placeholder = @"Find";
    _field.autocorrectionType = UITextAutocorrectionTypeNo;
    _field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _field.returnKeyType = UIReturnKeySearch;
    _field.clearButtonMode = UITextFieldViewModeWhileEditing;
    [_field addTarget:self action:@selector(revenant_searchFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [_navigator addSubview:_field];

    _count = [[UILabel alloc] initWithFrame:CGRectZero];
    _count.tag = 2;
    _count.backgroundColor = [UIColor clearColor];
    _count.font = [UIFont systemFontOfSize:14];
    _count.textColor = [UIColor darkGrayColor];
    _count.textAlignment = NSTextAlignmentCenter;
    [_navigator addSubview:_count];

    _previous = [self revenant_navigatorButtonWithTitle:@"‹" action:@selector(findPrevious) tag:3];
    _next = [self revenant_navigatorButtonWithTitle:@"›" action:@selector(findNext) tag:4];
    [self revenant_navigatorButtonWithTitle:@"Done" action:@selector(dismissFindNavigator) tag:5];
}

- (UIButton *)revenant_navigatorButtonWithTitle:(NSString *)title action:(SEL)action tag:(NSInteger)tag
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = tag;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_navigator addSubview:button];
    return button;
}

@end
