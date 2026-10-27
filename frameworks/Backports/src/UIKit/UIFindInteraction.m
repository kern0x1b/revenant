#import <UIKit/UIKit.h>

@interface UIFindSession (RevenantFindNavigation)
- (void)revenant_clearHighlight;
- (void)revenant_setBottomObstruction:(CGFloat)height;
@end

@interface RevenantFindNavigator : UIView
@property (nonatomic) BOOL showsReplaceRow;
@end

@implementation RevenantFindNavigator

@synthesize showsReplaceRow = _showsReplaceRow;

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), row = 44;
    UIView *field = [self viewWithTag:1], *count = [self viewWithTag:2];
    UIView *previous = [self viewWithTag:3], *next = [self viewWithTag:4], *done = [self viewWithTag:5];
    done.frame = CGRectMake(width - 64, 0, 60, row);
    next.frame = CGRectMake(CGRectGetMinX(done.frame) - 40, 0, 40, row);
    previous.frame = CGRectMake(CGRectGetMinX(next.frame) - 40, 0, 40, row);
    count.frame = CGRectMake(CGRectGetMinX(previous.frame) - 90, 0, 90, row);
    field.frame = CGRectMake(6, 7, MAX(0, CGRectGetMinX(count.frame) - 12), row - 14);
    UIView *replaceField = [self viewWithTag:6], *replace = [self viewWithTag:7], *replaceAll = [self viewWithTag:8];
    replaceAll.frame = CGRectMake(width - 116, row, 110, row);
    replace.frame = CGRectMake(CGRectGetMinX(replaceAll.frame) - 84, row, 80, row);
    replaceField.frame = CGRectMake(6, row + 7, MAX(0, CGRectGetMinX(replace.frame) - 12), row - 14);
    BOOL replaceRow = self.showsReplaceRow;
    replaceField.hidden = replace.hidden = replaceAll.hidden = !replaceRow;
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
    BOOL _showingReplace;
    RevenantFindNavigator *_navigator;
    UITextField *_field;
    UILabel *_count;
    UIButton *_previous;
    UIButton *_next;
    UITextField *_replaceField;
    UIButton *_replaceButton;
    UIButton *_replaceAllButton;
    CGFloat _keyboardOverlap;
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
    if (_replaceField)
        _replaceField.text = replacementText;
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
    _showingReplace = showingReplace && session.supportsReplacement;
    [self revenant_showNavigator];
    if ([_delegate respondsToSelector:@selector(findInteraction:didBeginFindSession:)])
        [_delegate findInteraction:self didBeginFindSession:session];
}

- (void)dismissFindNavigator
{
    if (!_findNavigatorVisible)
        return;
    _findNavigatorVisible = NO;
    _showingReplace = NO;
    UIFindSession *session = _activeFindSession;
    [self revenant_stopObserving];
    _keyboardOverlap = 0;
    [session revenant_setBottomObstruction:0];
    [_field resignFirstResponder];
    [_replaceField resignFirstResponder];
    [_navigator removeFromSuperview];
    [session revenant_clearHighlight];
    if ([_delegate respondsToSelector:@selector(findInteraction:didEndFindSession:)])
        [_delegate findInteraction:self didEndFindSession:session];
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
            if (!total)
                text = @"No results";
            else if (index == NSNotFound)
                text = total == 1 ? @"1 result" : [NSString stringWithFormat:@"%ld results", (long)total];
            else
                text = [NSString stringWithFormat:@"%ld of %ld", (long)(index + 1), (long)total];
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
    _replaceButton.enabled = total > 0 && session.supportsReplacement;
    _replaceAllButton.enabled = total > 0 && session.supportsReplacement;
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

- (void)revenant_replacementFieldChanged
{
    _replacementText = [_replaceField.text copy];
}

- (void)revenant_replaceCurrent
{
    UIFindSession *session = _activeFindSession;
    if (!_findNavigatorVisible || !session)
        return;
    [session performSingleReplacementWithSearchQuery:_searchText replacementString:_replacementText options:nil];
    [self updateResultCount];
}

- (void)revenant_replaceAll
{
    UIFindSession *session = _activeFindSession;
    if (!_findNavigatorVisible || !session)
        return;
    [session replaceAllInstancesOfSearchQuery:_searchText withReplacementString:_replacementText options:nil];
    [self updateResultCount];
}

- (void)revenant_showNavigator
{
    if (!_navigator)
        [self revenant_buildNavigator];
    _field.text = _searchText;
    _replaceField.text = _replacementText;
    _navigator.showsReplaceRow = _showingReplace;
    _navigator.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_view addSubview:_navigator];
    [self revenant_startObserving];
    [self revenant_layoutNavigator];
    [self revenant_search];
}

- (void)revenant_layoutNavigator
{
    CGFloat height = _navigator.showsReplaceRow ? 88 : 44;
    CGRect bounds = _view.bounds;
    _navigator.frame = CGRectMake(0, CGRectGetHeight(bounds) - _keyboardOverlap - height, CGRectGetWidth(bounds), height);
    [_activeFindSession revenant_setBottomObstruction:height + _keyboardOverlap];
}

- (void)revenant_startObserving
{
    [self revenant_stopObserving];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(revenant_keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [center addObserver:self selector:@selector(revenant_resultsChanged:) name:@"RevenantFindSessionResultsDidChange" object:nil];
}

- (void)revenant_stopObserving
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)revenant_keyboardChanged:(NSNotification *)notification
{
    UIWindow *window = _view.window;
    if (!window)
        return;
    CGRect frame = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboard = [_view convertRect:[window convertRect:frame fromWindow:nil] fromView:window];
    _keyboardOverlap = MAX(0, CGRectGetMaxY(_view.bounds) - CGRectGetMinY(keyboard));
    if (_findNavigatorVisible)
        [self revenant_layoutNavigator];
}

- (void)revenant_resultsChanged:(NSNotification *)notification
{
    if (_findNavigatorVisible && notification.object == _activeFindSession)
        [self updateResultCount];
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

    _previous = [self revenant_navigatorButtonWithTitle:[NSString stringWithFormat:@"%C", (unichar)0x2039] action:@selector(findPrevious) tag:3];
    _next = [self revenant_navigatorButtonWithTitle:[NSString stringWithFormat:@"%C", (unichar)0x203A] action:@selector(findNext) tag:4];
    [self revenant_navigatorButtonWithTitle:@"Done" action:@selector(dismissFindNavigator) tag:5];

    _replaceField = [[UITextField alloc] initWithFrame:CGRectZero];
    _replaceField.tag = 6;
    _replaceField.borderStyle = UITextBorderStyleRoundedRect;
    _replaceField.placeholder = @"Replace";
    _replaceField.text = _replacementText;
    _replaceField.autocorrectionType = UITextAutocorrectionTypeNo;
    _replaceField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _replaceField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [_replaceField addTarget:self action:@selector(revenant_replacementFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [_navigator addSubview:_replaceField];

    _replaceButton = [self revenant_navigatorButtonWithTitle:@"Replace" action:@selector(revenant_replaceCurrent) tag:7];
    _replaceAllButton = [self revenant_navigatorButtonWithTitle:@"Replace All" action:@selector(revenant_replaceAll) tag:8];
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
