#import <UIKit/UIKit.h>

// UIFindInteraction, iOS 16. The find navigator's state and the delegate's conversation about it, without the navigator's drawing: the port
// shows no find bar. Presenting asks the delegate for a session for the view the interaction is attached to, as the host does
// (tests/backports/host/find-interaction); a session given makes it the active one, shows the navigator and tells the delegate the search began,
// and a nil session leaves the navigator hidden and says nothing more. A session already active is reused without asking. Dismissing a shown navigator hides it and tells the delegate the search
// ended, and the active session stays set, as on the host. The search text and the replacement text are kept as the object given, not copied.
// Presenting an interaction that is not attached to a view does nothing: the host's answer there is not measured.
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
    // A session the interaction already holds is reused, as on the host (measured: after a dismissal the active session stays, and presenting
    // again does not ask the delegate for one). Otherwise the delegate is asked for a session for the view.
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

// The search steps need a session with results, and the port has none: they do nothing, as they do with no results on the host.
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
