#import <objc/message.h>
#import <objc/runtime.h>
#import "RevenantScenes.h"

static UIWindowScene *revenant_scene_object;
static NSURL *revenant_launch_url;
static UISceneConnectionOptions *revenant_launch_options;
static BOOL revenant_connected;

static NSDictionary *revenant_manifest_entry(NSString *name)
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

static void revenant_fill_configuration(UISceneConfiguration *configuration, NSDictionary *entry)
{
    NSString *sceneClass = entry[@"UISceneClassName"], *delegateClass = entry[@"UISceneDelegateClassName"], *storyboard = entry[@"UISceneStoryboardFile"];
    if (sceneClass && !configuration.sceneClass)
        configuration.sceneClass = NSClassFromString(sceneClass);
    if (delegateClass && !configuration.delegateClass)
        configuration.delegateClass = NSClassFromString(delegateClass);
    if (storyboard && !configuration.storyboard)
        configuration.storyboard = [UIStoryboard storyboardWithName:storyboard bundle:nil];
}

static UISceneConfiguration *revenant_manifest_configuration(void)
{
    NSDictionary *entry = revenant_manifest_entry(nil);
    UISceneConfiguration *configuration = [UISceneConfiguration configurationWithName:entry[@"UISceneConfigurationName"] sessionRole:UIWindowSceneSessionRoleApplication];
    revenant_fill_configuration(configuration, entry);
    return configuration;
}

static NSString *revenant_session_identifier(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = @"space.kern0x1b.revenant.UISceneSessionIdentifier";
    NSString *identifier = [defaults stringForKey:key];
    if (!identifier) {
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        identifier = CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
        CFRelease(uuid);
        [defaults setObject:identifier forKey:key];
    }
    return identifier;
}

static NSString *revenant_restoration_key(void)
{
    return [@"space.kern0x1b.revenant.UISceneStateRestoration." stringByAppendingString:revenant_session_identifier()];
}

static NSSet *revenant_restoration_classes(void)
{
    static NSSet *classes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        classes = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSSet class], [NSString class],
                                        [NSNumber class], [NSDate class], [NSData class], [NSURL class], [NSUUID class], [NSNull class], nil];
    });
    return classes;
}

static NSData *revenant_archive_activity(NSUserActivity *activity)
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

static id revenant_kept(id value, Class wanted)
{
    return [value isKindOfClass:wanted] ? value : nil;
}

static NSUserActivity *revenant_unarchive_activity(NSData *data)
{
    NSError *error = nil;
    NSDictionary *record = nil;
    @try {
        record = [NSKeyedUnarchiver unarchivedObjectOfClasses:revenant_restoration_classes() fromData:data error:&error];
    } @catch (NSException *exception) {
        return nil;
    }
    if (![record isKindOfClass:[NSDictionary class]] || ![record[@"type"] isKindOfClass:[NSString class]])
        return nil;
    NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:record[@"type"]];
    activity.title = revenant_kept(record[@"title"], [NSString class]);
    NSDictionary *userInfo = revenant_kept(record[@"userInfo"], [NSDictionary class]);
    if (userInfo)
        activity.userInfo = userInfo;
    activity.webpageURL = revenant_kept(record[@"webpageURL"], [NSURL class]);
    activity.requiredUserInfoKeys = revenant_kept(record[@"requiredUserInfoKeys"], [NSSet class]);
    activity.expirationDate = revenant_kept(record[@"expirationDate"], [NSDate class]);
    activity.keywords = revenant_kept(record[@"keywords"], [NSSet class]);
    return activity;
}

static void revenant_save_restoration(void)
{
    UIScene *scene = revenant_scene_object;
    id<UISceneDelegate> delegate = scene.delegate;
    if (!scene || !revenant_connected || ![delegate respondsToSelector:@selector(stateRestorationActivityForScene:)])
        return;
    NSUserActivity *activity = [delegate stateRestorationActivityForScene:scene];
    NSData *data = activity ? revenant_archive_activity(activity) : nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (data)
        [defaults setObject:data forKey:revenant_restoration_key()];
    else
        [defaults removeObjectForKey:revenant_restoration_key()];
    [defaults synchronize];
}

static NSUserActivity *revenant_saved_restoration(void)
{
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:revenant_restoration_key()];
    return data ? revenant_unarchive_activity(data) : nil;
}

UIWindowScene *revenant_scene(void)
{
    @synchronized([UIApplication class]) {
        if (revenant_scene_object)
            return revenant_scene_object;
        id<UIApplicationDelegate> delegate = [UIApplication sharedApplication].delegate;
        if (!delegate)
            return nil;
        UISceneConfiguration *configuration = revenant_manifest_configuration();
        UISceneSession *session = [[UISceneSession alloc] initRevenantWithRole:UIWindowSceneSessionRoleApplication configuration:configuration
                                                          persistentIdentifier:revenant_session_identifier()];
        UISceneConnectionOptions *options = revenant_launch_options ?: [[UISceneConnectionOptions alloc] initRevenantWithURLContexts:nil sourceApplication:nil];
        if ([delegate respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)]) {
            UISceneConfiguration *chosen = [[delegate application:[UIApplication sharedApplication] configurationForConnectingSceneSession:session options:options] copy];
            if (chosen) {
                if (chosen.name)
                    revenant_fill_configuration(chosen, revenant_manifest_entry(chosen.name));
                session = [[UISceneSession alloc] initRevenantWithRole:UIWindowSceneSessionRoleApplication configuration:chosen persistentIdentifier:session.persistentIdentifier];
            }
        }
        Class sceneClass = session.configuration.sceneClass ?: [UIWindowScene class];
        revenant_scene_object = [[sceneClass alloc] initWithSession:session connectionOptions:options];
        return revenant_scene_object;
    }
}

static void revenant_post(NSNotificationName name, UIScene *scene)
{
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:scene];
}

static void revenant_transition(UISceneActivationState state, SEL callback, NSNotificationName name)
{
    UIScene *scene = revenant_scene_object;
    if (!scene || !revenant_connected)
        return;
    [scene revenant_setActivationState:state];
    id<UISceneDelegate> delegate = scene.delegate;
    if ([delegate respondsToSelector:callback])
        ((void (*)(id, SEL, UIScene *))objc_msgSend)(delegate, callback, scene);
    revenant_post(name, scene);
}

static void revenant_enter_foreground(void)
{
    if (revenant_scene_object.activationState == UISceneActivationStateBackground)
        revenant_transition(UISceneActivationStateForegroundInactive, @selector(sceneWillEnterForeground:), UISceneWillEnterForegroundNotification);
}

static UIOpenURLContext *revenant_context(NSURL *url, NSString *source, id annotation)
{
    UISceneOpenURLOptions *options = [[UISceneOpenURLOptions alloc] initRevenantWithSourceApplication:source annotation:annotation openInPlace:NO];
    return [[UIOpenURLContext alloc] initRevenantWithURL:url options:options];
}

static void revenant_hook_open_url(id delegate)
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
        UIScene *scene = revenant_scene_object;
        id<UISceneDelegate> sceneDelegate = scene.delegate;
        if (revenant_launch_url && [revenant_launch_url isEqual:url]) {
            revenant_launch_url = nil;
            return YES;
        }
        if ([sceneDelegate respondsToSelector:@selector(scene:openURLContexts:)]) {
            [sceneDelegate scene:scene openURLContexts:[NSSet setWithObject:revenant_context(url, source, annotation)]];
            return YES;
        }
        return original ? ((BOOL (*)(id, SEL, UIApplication *, NSURL *, NSString *, id))original)(self, selector, application, url, source, annotation) : NO;
    });
    if (!class_addMethod(cls, selector, replacement, "c@:@@@@"))
        method_setImplementation(existing, replacement);
}

static void revenant_connect(NSDictionary *launchOptions)
{
    NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
    NSString *source = launchOptions[UIApplicationLaunchOptionsSourceApplicationKey];
    NSSet *contexts = url ? [NSSet setWithObject:revenant_context(url, source, launchOptions[UIApplicationLaunchOptionsAnnotationKey])] : nil;
    revenant_launch_url = url;
    revenant_launch_options = [[UISceneConnectionOptions alloc] initRevenantWithURLContexts:contexts sourceApplication:source];
    UIWindowScene *scene = revenant_scene();
    if (!scene)
        return;
    NSUserActivity *restored = revenant_saved_restoration();
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
    revenant_connected = YES;
    if ([delegate respondsToSelector:@selector(scene:willConnectToSession:options:)])
        [delegate scene:scene willConnectToSession:scene.session options:revenant_launch_options];
    if (restored && [delegate respondsToSelector:@selector(scene:restoreInteractionStateWithUserActivity:)])
        [delegate scene:scene restoreInteractionStateWithUserActivity:restored];
    [scene revenant_setActivationState:UISceneActivationStateBackground];
    revenant_post(UISceneWillConnectNotification, scene);
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
        revenant_enter_foreground();
    id appDelegate = [UIApplication sharedApplication].delegate;
    if ([delegate respondsToSelector:@selector(scene:openURLContexts:)] || [appDelegate respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)])
        revenant_hook_open_url(appDelegate);
}

@interface RevenantSceneObserver : NSObject
@end

@implementation RevenantSceneObserver

+ (void)load
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *launched) {
        revenant_connect(launched.userInfo);
    }];
    [center addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        revenant_enter_foreground();
    }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        revenant_enter_foreground();
        if (revenant_scene_object.activationState == UISceneActivationStateForegroundInactive)
            revenant_transition(UISceneActivationStateForegroundActive, @selector(sceneDidBecomeActive:), UISceneDidActivateNotification);
    }];
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        if (revenant_scene_object.activationState == UISceneActivationStateForegroundActive)
            revenant_transition(UISceneActivationStateForegroundInactive, @selector(sceneWillResignActive:), UISceneWillDeactivateNotification);
    }];
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        if (revenant_scene_object.activationState == UISceneActivationStateForegroundActive)
            revenant_transition(UISceneActivationStateForegroundInactive, @selector(sceneWillResignActive:), UISceneWillDeactivateNotification);
        if (revenant_scene_object.activationState == UISceneActivationStateForegroundInactive)
            revenant_transition(UISceneActivationStateBackground, @selector(sceneDidEnterBackground:), UISceneDidEnterBackgroundNotification);
        revenant_save_restoration();
    }];
    [center addObserverForName:UIApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        revenant_save_restoration();
    }];
}

@end
