#import "CharonScenes.h"

@implementation UIScene {
    UISceneSession *_session;
    id<UISceneDelegate> _delegate;
    UISceneActivationState _activationState;
    NSString *_title;
    NSString *_subtitle;
    UISceneActivationConditions *_activationConditions;
}

- (instancetype)initWithSession:(UISceneSession *)session connectionOptions:(UISceneConnectionOptions *)connectionOptions
{
    if ((self = [super init])) {
        _session = session;
        _activationState = UISceneActivationStateUnattached;
        _activationConditions = [[UISceneActivationConditions alloc] init];
        [session charon_setScene:self];
    }
    return self;
}

- (UISceneSession *)session
{
    return _session;
}

- (id<UISceneDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UISceneDelegate>)delegate
{
    _delegate = delegate;
}

- (UISceneActivationState)activationState
{
    return _activationState;
}

- (void)charon_setActivationState:(UISceneActivationState)state
{
    _activationState = state;
}

- (NSString *)title
{
    return _title ?: @"";
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
}

// The subtitle is kept as the object given, not copied, although the header says copy: the host keeps the same object (tests/backports/host/scene-subtitle),
// and a string changed after it was set shows through. Nil is kept as the empty string, which is what the host answers after nil is set; a
// scene never given one answers nil.
- (NSString *)subtitle
{
    return _subtitle;
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitle = subtitle ?: @"";
}

- (UISceneActivationConditions *)activationConditions
{
    return _activationConditions;
}

- (void)setActivationConditions:(UISceneActivationConditions *)activationConditions
{
    _activationConditions = activationConditions;
}

- (void)openURL:(NSURL *)url options:(UISceneOpenExternalURLOptions *)options completionHandler:(void (^)(BOOL))completion
{
    BOOL opened = !options.universalLinksOnly && [[UIApplication sharedApplication] openURL:url];
    if (completion)
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(opened);
        });
}

@end
