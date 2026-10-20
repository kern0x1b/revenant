#import <UIKit/UIKit.h>

@implementation UIFindInteraction {
@private
    __weak id<UIFindInteractionDelegate> _delegate;
    __weak UIView *_view;
    NSString *_searchText;
    NSString *_replacementText;
    UIMenu *(^_optionsMenuProvider)(NSArray<UIMenuElement *> *defaultOptions);
    UIFindSession *_activeFindSession;
    BOOL _findNavigatorVisible;
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
    _searchText = searchText;
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
    if (!session)
        return;
    _activeFindSession = session;
    _findNavigatorVisible = YES;
    if ([_delegate respondsToSelector:@selector(findInteraction:didBeginFindSession:)])
        [_delegate findInteraction:self didBeginFindSession:session];
}

- (void)dismissFindNavigator
{
    if (!_findNavigatorVisible)
        return;
    _findNavigatorVisible = NO;
    if ([_delegate respondsToSelector:@selector(findInteraction:didEndFindSession:)])
        [_delegate findInteraction:self didEndFindSession:_activeFindSession];
}

- (void)findNext
{
}

- (void)findPrevious
{
}

- (void)updateResultCount
{
}

@end
