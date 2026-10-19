#import "CharonScenes.h"

@implementation UIOpenURLContext {
    NSURL *_URL;
    UISceneOpenURLOptions *_options;
}

- (instancetype)initCharonWithURL:(NSURL *)URL options:(UISceneOpenURLOptions *)options
{
    if ((self = [super init])) {
        _URL = [URL copy];
        _options = options;
    }
    return self;
}

- (NSURL *)URL
{
    return _URL;
}

- (UISceneOpenURLOptions *)options
{
    return _options;
}

@end

@implementation UISceneOpenURLOptions {
    NSString *_sourceApplication;
    id _annotation;
    BOOL _openInPlace;
    UIEventAttribution *_eventAttribution;
}

- (UIEventAttribution *)eventAttribution
{
    return _eventAttribution;
}

- (instancetype)initCharonWithSourceApplication:(NSString *)sourceApplication annotation:(id)annotation openInPlace:(BOOL)openInPlace
{
    if ((self = [super init])) {
        _sourceApplication = [sourceApplication copy];
        _annotation = annotation;
        _openInPlace = openInPlace;
    }
    return self;
}

- (NSString *)sourceApplication
{
    return _sourceApplication;
}

- (id)annotation
{
    return _annotation;
}

- (BOOL)openInPlace
{
    return _openInPlace;
}

@end

@implementation UISceneConnectionOptions {
    NSSet *_URLContexts;
    NSString *_sourceApplication;
}

- (instancetype)initCharonWithURLContexts:(NSSet *)URLContexts sourceApplication:(NSString *)sourceApplication
{
    if ((self = [super init])) {
        _URLContexts = [URLContexts copy];
        _sourceApplication = [sourceApplication copy];
    }
    return self;
}

- (NSSet *)URLContexts
{
    return _URLContexts ?: [NSSet set];
}

- (NSString *)sourceApplication
{
    return _sourceApplication;
}

- (NSString *)handoffUserActivityType
{
    return nil;
}

- (NSSet *)userActivities
{
    return [NSSet set];
}

- (id)notificationResponse
{
    return nil;
}

- (id)shortcutItem
{
    return nil;
}

- (id)cloudKitShareMetadata
{
    return nil;
}

@end

@implementation UISceneConfiguration {
    NSString *_name;
    UISceneSessionRole _role;
    Class _sceneClass;
    Class _delegateClass;
    UIStoryboard *_storyboard;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)configurationWithName:(NSString *)name sessionRole:(UISceneSessionRole)sessionRole
{
    return [[self alloc] initWithName:name sessionRole:sessionRole];
}

- (instancetype)initWithName:(NSString *)name sessionRole:(UISceneSessionRole)sessionRole
{
    if ((self = [super init])) {
        _name = [name copy];
        _role = [sessionRole copy];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithName:nil sessionRole:@"UISceneSessionRoleNone"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self initWithName:[coder decodeObjectOfClass:[NSString class] forKey:@"name"] sessionRole:[coder decodeObjectOfClass:[NSString class] forKey:@"role"]])) {
        NSString *sceneClass = [coder decodeObjectOfClass:[NSString class] forKey:@"sceneClass"];
        NSString *delegateClass = [coder decodeObjectOfClass:[NSString class] forKey:@"delegateClass"];
        _sceneClass = sceneClass ? NSClassFromString(sceneClass) : Nil;
        _delegateClass = delegateClass ? NSClassFromString(delegateClass) : Nil;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_role forKey:@"role"];
    if (_sceneClass)
        [coder encodeObject:NSStringFromClass(_sceneClass) forKey:@"sceneClass"];
    if (_delegateClass)
        [coder encodeObject:NSStringFromClass(_delegateClass) forKey:@"delegateClass"];
}

- (id)copyWithZone:(NSZone *)zone
{
    UISceneConfiguration *copy = [[[self class] allocWithZone:zone] initWithName:_name sessionRole:_role];
    copy->_sceneClass = _sceneClass;
    copy->_delegateClass = _delegateClass;
    copy->_storyboard = _storyboard;
    return copy;
}

- (NSString *)name
{
    return _name;
}

- (UISceneSessionRole)role
{
    return _role;
}

- (Class)sceneClass
{
    return _sceneClass;
}

- (void)setSceneClass:(Class)sceneClass
{
    _sceneClass = sceneClass;
}

- (Class)delegateClass
{
    return _delegateClass;
}

- (void)setDelegateClass:(Class)delegateClass
{
    _delegateClass = delegateClass;
}

- (UIStoryboard *)storyboard
{
    return _storyboard;
}

- (void)setStoryboard:(UIStoryboard *)storyboard
{
    _storyboard = storyboard;
}

@end

@implementation UISceneSession {
    __weak UIScene *_scene;
    UISceneSessionRole _role;
    UISceneConfiguration *_configuration;
    NSString *_persistentIdentifier;
    NSUserActivity *_stateRestorationActivity;
    NSDictionary *_userInfo;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initCharonWithRole:(UISceneSessionRole)role configuration:(UISceneConfiguration *)configuration persistentIdentifier:(NSString *)persistentIdentifier
{
    if ((self = [super init])) {
        _role = [role copy];
        _configuration = [configuration copy];
        _persistentIdentifier = [persistentIdentifier copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    UISceneConfiguration *configuration = [coder decodeObjectOfClass:[UISceneConfiguration class] forKey:@"configuration"];
    return [self initCharonWithRole:[coder decodeObjectOfClass:[NSString class] forKey:@"role"] configuration:configuration
               persistentIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"persistentIdentifier"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_role forKey:@"role"];
    [coder encodeObject:_configuration forKey:@"configuration"];
    [coder encodeObject:_persistentIdentifier forKey:@"persistentIdentifier"];
}

- (void)charon_setScene:(UIScene *)scene
{
    _scene = scene;
}

- (UIScene *)scene
{
    return _scene;
}

- (UISceneSessionRole)role
{
    return _role;
}

- (UISceneConfiguration *)configuration
{
    return [_configuration copy];
}

- (NSString *)persistentIdentifier
{
    return _persistentIdentifier;
}

- (NSUserActivity *)stateRestorationActivity
{
    return _stateRestorationActivity;
}

- (void)setStateRestorationActivity:(NSUserActivity *)stateRestorationActivity
{
    _stateRestorationActivity = stateRestorationActivity;
}

- (NSDictionary *)userInfo
{
    return _userInfo;
}

- (void)setUserInfo:(NSDictionary *)userInfo
{
    _userInfo = [userInfo copy];
}

@end

@implementation UISceneSizeRestrictions {
    CGSize _minimumSize;
    CGSize _maximumSize;
    BOOL _allowsFullScreen;
}

- (CGSize)minimumSize
{
    return _minimumSize;
}

- (void)setMinimumSize:(CGSize)minimumSize
{
    _minimumSize = minimumSize;
}

- (CGSize)maximumSize
{
    return _maximumSize;
}

- (void)setMaximumSize:(CGSize)maximumSize
{
    _maximumSize = maximumSize;
}

- (BOOL)allowsFullScreen
{
    return _allowsFullScreen;
}

- (void)setAllowsFullScreen:(BOOL)allowsFullScreen
{
    _allowsFullScreen = allowsFullScreen;
}

@end

@implementation UISceneActivationConditions {
    NSPredicate *_canActivate;
    NSPredicate *_prefersToActivate;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _canActivate = [NSPredicate predicateWithValue:YES];
        _prefersToActivate = [NSPredicate predicateWithValue:NO];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _canActivate = [NSPredicate predicateWithValue:YES];
        _prefersToActivate = [NSPredicate predicateWithValue:NO];
        NSPredicate *can = [coder decodeObjectOfClass:[NSPredicate class] forKey:@"canActivate"];
        NSPredicate *prefers = [coder decodeObjectOfClass:[NSPredicate class] forKey:@"prefersToActivate"];
        if (can)
            _canActivate = can;
        if (prefers)
            _prefersToActivate = prefers;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_canActivate forKey:@"canActivate"];
    [coder encodeObject:_prefersToActivate forKey:@"prefersToActivate"];
}

- (NSPredicate *)canActivateForTargetContentIdentifierPredicate
{
    return _canActivate;
}

- (void)setCanActivateForTargetContentIdentifierPredicate:(NSPredicate *)predicate
{
    _canActivate = [predicate copy];
}

- (NSPredicate *)prefersToActivateForTargetContentIdentifierPredicate
{
    return _prefersToActivate;
}

- (void)setPrefersToActivateForTargetContentIdentifierPredicate:(NSPredicate *)predicate
{
    _prefersToActivate = [predicate copy];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
#pragma clang diagnostic ignored "-Wmismatched-return-types"
@implementation UISceneActivationRequestOptions {
    UIScene *_requestingScene;
    NSInteger _collectionJoinBehavior;
}

- (NSInteger)collectionJoinBehavior
{
    return _collectionJoinBehavior;
}

- (void)setCollectionJoinBehavior:(NSInteger)collectionJoinBehavior
{
    _collectionJoinBehavior = collectionJoinBehavior;
}

- (UIScene *)requestingScene
{
    return _requestingScene;
}

- (void)setRequestingScene:(UIScene *)requestingScene
{
    _requestingScene = requestingScene;
}

#pragma clang diagnostic pop
@end

@implementation UISceneDestructionRequestOptions
@end

@implementation UIWindowSceneDestructionRequestOptions {
    UIWindowSceneDismissalAnimation _windowDismissalAnimation;
}

- (UIWindowSceneDismissalAnimation)windowDismissalAnimation
{
    return _windowDismissalAnimation;
}

- (void)setWindowDismissalAnimation:(UIWindowSceneDismissalAnimation)windowDismissalAnimation
{
    _windowDismissalAnimation = windowDismissalAnimation;
}

@end

@implementation UISceneOpenExternalURLOptions {
    BOOL _universalLinksOnly;
    UIEventAttribution *_eventAttribution;
}

- (UIEventAttribution *)eventAttribution
{
    return _eventAttribution;
}

- (void)setEventAttribution:(UIEventAttribution *)eventAttribution
{
    _eventAttribution = [eventAttribution copy];
}

- (BOOL)universalLinksOnly
{
    return _universalLinksOnly;
}

- (void)setUniversalLinksOnly:(BOOL)universalLinksOnly
{
    _universalLinksOnly = universalLinksOnly;
}

@end
