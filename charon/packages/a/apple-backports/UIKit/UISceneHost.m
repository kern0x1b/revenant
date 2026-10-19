#import <objc/message.h>
#import <objc/runtime.h>
#import "CharonScenes.h"

static UIWindowScene *charon_scene_object;
static NSURL *charon_launch_url;
static UISceneConnectionOptions *charon_launch_options;
static BOOL charon_connected;

static NSDictionary *charon_manifest_entry(NSString *name)
{
    NSDictionary *manifest = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationSceneManifest"];
    NSDictionary *configurations = [manifest isKindOfClass:[NSDictionary class]] ? manifest[@"UISceneConfigurations"] : nil;
    NSArray *entries = [configurations isKindOfClass:[NSDictionary class]] ? configurations[UIWindowSceneSessionRoleApplication] : nil;
    if (![entries isKindOfClass:[NSArray class]])
        return nil;
    for (NSDictionary *entry in entries)
        if ([entry isKindOfClass:[NSDictionary class]] && (!name || [entry[@"UISceneConfigurationName"] isEqual:name]))
            return entry;
    return nil;
}

static void charon_fill_configuration(UISceneConfiguration *configuration, NSDictionary *entry)
{
    NSString *sceneClass = entry[@"UISceneClassName"], *delegateClass = entry[@"UISceneDelegateClassName"], *storyboard = entry[@"UISceneStoryboardFile"];
    if (sceneClass && !configuration.sceneClass)
        configuration.sceneClass = NSClassFromString(sceneClass);
    if (delegateClass && !configuration.delegateClass)
        configuration.delegateClass = NSClassFromString(delegateClass);
    if (storyboard && !configuration.storyboard)
        configuration.storyboard = [UIStoryboard storyboardWithName:storyboard bundle:nil];
}

static UISceneConfiguration *charon_manifest_configuration(void)
{
    NSDictionary *entry = charon_manifest_entry(nil);
    UISceneConfiguration *configuration = [UISceneConfiguration configurationWithName:entry[@"UISceneConfigurationName"] sessionRole:UIWindowSceneSessionRoleApplication];
    charon_fill_configuration(configuration, entry);
    return configuration;
}

static NSString *charon_session_identifier(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = @"space.kern0x1b.charon.UISceneSessionIdentifier";
    NSString *identifier = [defaults stringForKey:key];
    if (!identifier) {
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        identifier = CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
        CFRelease(uuid);
        [defaults setObject:identifier forKey:key];
    }
    return identifier;
}

static NSString *charon_restoration_key(void)
{
    return [@"space.kern0x1b.charon.UISceneStateRestoration." stringByAppendingString:charon_session_identifier()];
}

static NSSet *charon_restoration_classes(void)
{
    static NSSet *classes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        classes = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSSet class], [NSString class],
                                        [NSNumber class], [NSDate class], [NSData class], [NSURL class], [NSUUID class], [NSNull class], nil];
    });
    return classes;
}

static NSData *charon_archive_activity(NSUserActivity *activity)
{
    NSMutableDictionary *record = [NSMutableDictionary dictionary];
    record[@"type"] = activity.activityType;
    if (activity.title)
        record[@"title"] = activity.title;
    if (activity.userInfo)
        record[@"userInfo"] = activity.userInfo;
    if (activity.webpageURL)
        record[@"webpageURL"] = activity.webpageURL;
    if (activity.requiredUserInfoKeys)
        record[@"requiredUserInfoKeys"] = activity.requiredUserInfoKeys;
    if (activity.expirationDate)
        record[@"expirationDate"] = activity.expirationDate;
    if (activity.keywords)
        record[@"keywords"] = activity.keywords;
    NSError *error = nil;
    NSData *data = nil;
    @try {
        data = [NSKeyedArchiver archivedDataWithRootObject:record requiringSecureCoding:YES error:&error];
    } @catch (NSException *exception) {
        return nil;
    }
    return data;
}

static id charon_kept(id value, Class wanted)
{
    return [value isKindOfClass:wanted] ? value : nil;
}

static NSUserActivity *charon_unarchive_activity(NSData *data)
{
    NSError *error = nil;
    NSDictionary *record = nil;
    @try {
        record = [NSKeyedUnarchiver unarchivedObjectOfClasses:charon_restoration_classes() fromData:data error:&error];
    } @catch (NSException *exception) {
        return nil;
    }
    if (![record isKindOfClass:[NSDictionary class]] || ![record[@"type"] isKindOfClass:[NSString class]])
        return nil;
    NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:record[@"type"]];
    activity.title = charon_kept(record[@"title"], [NSString class]);
    NSDictionary *userInfo = charon_kept(record[@"userInfo"], [NSDictionary class]);
    if (userInfo)
        activity.userInfo = userInfo;
    activity.webpageURL = charon_kept(record[@"webpageURL"], [NSURL class]);
    activity.requiredUserInfoKeys = charon_kept(record[@"requiredUserInfoKeys"], [NSSet class]);
    activity.expirationDate = charon_kept(record[@"expirationDate"], [NSDate class]);
    activity.keywords = charon_kept(record[@"keywords"], [NSSet class]);
    return activity;
}

static void charon_save_restoration(void)
{
    UIScene *scene = charon_scene_object;
    id<UISceneDelegate> delegate = scene.delegate;
    if (!scene || !charon_connected || ![delegate respondsToSelector:@selector(stateRestorationActivityForScene:)])
        return;
    NSUserActivity *activity = [delegate stateRestorationActivityForScene:scene];
    NSData *data = activity ? charon_archive_activity(activity) : nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (data)
        [defaults setObject:data forKey:charon_restoration_key()];
    else
        [defaults removeObjectForKey:charon_restoration_key()];
    [defaults synchronize];
}

static NSUserActivity *charon_saved_restoration(void)
{
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:charon_restoration_key()];
    return data ? charon_unarchive_activity(data) : nil;
}

UIWindowScene *charon_scene(void)
{
    @synchronized([UIApplication class]) {
        if (charon_scene_object)
            return charon_scene_object;
        id<UIApplicationDelegate> delegate = [UIApplication sharedApplication].delegate;
        if (!delegate)
            return nil;
        UISceneConfiguration *configuration = charon_manifest_configuration();
        UISceneSession *session = [[UISceneSession alloc] initCharonWithRole:UIWindowSceneSessionRoleApplication configuration:configuration
                                                          persistentIdentifier:charon_session_identifier()];
        UISceneConnectionOptions *options = charon_launch_options ?: [[UISceneConnectionOptions alloc] initCharonWithURLContexts:nil sourceApplication:nil];
        if ([delegate respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)]) {
            UISceneConfiguration *chosen = [[delegate application:[UIApplication sharedApplication] configurationForConnectingSceneSession:session options:options] copy];
            if (chosen) {
                if (chosen.name)
                    charon_fill_configuration(chosen, charon_manifest_entry(chosen.name));
                session = [[UISceneSession alloc] initCharonWithRole:UIWindowSceneSessionRoleApplication configuration:chosen persistentIdentifier:session.persistentIdentifier];
            }
        }
        Class sceneClass = session.configuration.sceneClass ?: [UIWindowScene class];
        charon_scene_object = [[sceneClass alloc] initWithSession:session connectionOptions:options];
        return charon_scene_object;
    }
}

static void charon_post(NSNotificationName name, UIScene *scene)
{
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:scene];
}

static void charon_transition(UISceneActivationState state, SEL callback, NSNotificationName name)
{
    UIScene *scene = charon_scene_object;
    if (!scene || !charon_connected)
        return;
    [scene charon_setActivationState:state];
    id<UISceneDelegate> delegate = scene.delegate;
    if ([delegate respondsToSelector:callback])
        ((void (*)(id, SEL, UIScene *))objc_msgSend)(delegate, callback, scene);
    charon_post(name, scene);
}

static void charon_enter_foreground(void)
{
    if (charon_scene_object.activationState == UISceneActivationStateBackground)
        charon_transition(UISceneActivationStateForegroundInactive, @selector(sceneWillEnterForeground:), UISceneWillEnterForegroundNotification);
}

static UIOpenURLContext *charon_context(NSURL *url, NSString *source, id annotation)
{
    UISceneOpenURLOptions *options = [[UISceneOpenURLOptions alloc] initCharonWithSourceApplication:source annotation:annotation openInPlace:NO];
    return [[UIOpenURLContext alloc] initCharonWithURL:url options:options];
}

static void charon_hook_open_url(id delegate)
{
    Class cls = object_getClass(delegate);
    static char hooked;
    if ([objc_getAssociatedObject(cls, &hooked) boolValue])
        return;
    objc_setAssociatedObject(cls, &hooked, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SEL selector = @selector(application:openURL:sourceApplication:annotation:);
    Method existing = class_getInstanceMethod(cls, selector);
    IMP original = existing ? method_getImplementation(existing) : NULL;
    IMP replacement = imp_implementationWithBlock(^BOOL(id self, UIApplication *application, NSURL *url, NSString *source, id annotation) {
        UIScene *scene = charon_scene_object;
        id<UISceneDelegate> sceneDelegate = scene.delegate;
        if (charon_launch_url && [charon_launch_url isEqual:url]) {
            charon_launch_url = nil;
            return YES;
        }
        if ([sceneDelegate respondsToSelector:@selector(scene:openURLContexts:)]) {
            [sceneDelegate scene:scene openURLContexts:[NSSet setWithObject:charon_context(url, source, annotation)]];
            return YES;
        }
        return original ? ((BOOL (*)(id, SEL, UIApplication *, NSURL *, NSString *, id))original)(self, selector, application, url, source, annotation) : NO;
    });
    if (!class_addMethod(cls, selector, replacement, "c@:@@@@"))
        method_setImplementation(existing, replacement);
}

static void charon_connect(NSDictionary *launchOptions)
{
    NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
    NSString *source = launchOptions[UIApplicationLaunchOptionsSourceApplicationKey];
    NSSet *contexts = url ? [NSSet setWithObject:charon_context(url, source, launchOptions[UIApplicationLaunchOptionsAnnotationKey])] : nil;
    charon_launch_url = url;
    charon_launch_options = [[UISceneConnectionOptions alloc] initCharonWithURLContexts:contexts sourceApplication:source];
    UIWindowScene *scene = charon_scene();
    if (!scene)
        return;
    NSUserActivity *restored = charon_saved_restoration();
    if (restored)
        scene.session.stateRestorationActivity = restored;
    UISceneConfiguration *configuration = scene.session.configuration;
    Class delegateClass = configuration.delegateClass;
    if (delegateClass && !scene.delegate)
        scene.delegate = [[delegateClass alloc] init];
    id<UISceneDelegate> delegate = scene.delegate;
    if (configuration.storyboard) {
        UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
        window.rootViewController = [configuration.storyboard instantiateInitialViewController];
        if ([delegate respondsToSelector:@selector(setWindow:)])
            [(id<UIWindowSceneDelegate>)delegate setWindow:window];
        [window makeKeyAndVisible];
    }
    charon_connected = YES;
    if ([delegate respondsToSelector:@selector(scene:willConnectToSession:options:)])
        [delegate scene:scene willConnectToSession:scene.session options:charon_launch_options];
    if (restored && [delegate respondsToSelector:@selector(scene:restoreInteractionStateWithUserActivity:)])
        [delegate scene:scene restoreInteractionStateWithUserActivity:restored];
    [scene charon_setActivationState:UISceneActivationStateBackground];
    charon_post(UISceneWillConnectNotification, scene);
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
        charon_enter_foreground();
    id appDelegate = [UIApplication sharedApplication].delegate;
    if ([delegate respondsToSelector:@selector(scene:openURLContexts:)] || [appDelegate respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)])
        charon_hook_open_url(appDelegate);
}

@interface CharonSceneObserver : NSObject
@end

@implementation CharonSceneObserver

+ (void)load
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *launched) {
        charon_connect(launched.userInfo);
    }];
    [center addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        charon_enter_foreground();
    }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        charon_enter_foreground();
        if (charon_scene_object.activationState == UISceneActivationStateForegroundInactive)
            charon_transition(UISceneActivationStateForegroundActive, @selector(sceneDidBecomeActive:), UISceneDidActivateNotification);
    }];
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        if (charon_scene_object.activationState == UISceneActivationStateForegroundActive)
            charon_transition(UISceneActivationStateForegroundInactive, @selector(sceneWillResignActive:), UISceneWillDeactivateNotification);
    }];
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        if (charon_scene_object.activationState == UISceneActivationStateForegroundActive)
            charon_transition(UISceneActivationStateForegroundInactive, @selector(sceneWillResignActive:), UISceneWillDeactivateNotification);
        if (charon_scene_object.activationState == UISceneActivationStateForegroundInactive)
            charon_transition(UISceneActivationStateBackground, @selector(sceneDidEnterBackground:), UISceneDidEnterBackgroundNotification);
        charon_save_restoration();
    }];
    [center addObserverForName:UIApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        charon_save_restoration();
    }];
}

@end
