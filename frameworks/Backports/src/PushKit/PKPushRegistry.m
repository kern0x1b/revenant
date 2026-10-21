#import <PushKit/PushKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PKPushCredentials (RevenantPushKit)
- (instancetype)initWithRevenantType:(PKPushType)type token:(NSData *)token;
@end

static NSString *const RevenantPushTokenDefaultsKeyPrefix = @"org.revenant.backports.PKPushToken.";
static NSString *const RevenantRegisteredTypesKey = @"org.revenant.backports.UIUserNotificationTypes";

@interface PKPushRegistry (RevenantPushKit)
- (void)revenant_deliverToken:(NSData *)token forType:(PKPushType)type;
@end

static NSHashTable<PKPushRegistry *> *RevenantActivePushRegistries(void)
{
    static NSHashTable<PKPushRegistry *> *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSHashTable weakObjectsHashTable];
    });
    return table;
}

static void RevenantPushDeliverToken(NSData *token, PKPushType type)
{
    if (!token || !type)
        return;
    [[NSUserDefaults standardUserDefaults] setObject:token forKey:[RevenantPushTokenDefaultsKeyPrefix stringByAppendingString:type]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSHashTable *registries = RevenantActivePushRegistries();
    NSArray<PKPushRegistry *> *snapshot;
    @synchronized (registries) {
        snapshot = registries.allObjects;
    }
    for (PKPushRegistry *registry in snapshot)
        [registry revenant_deliverToken:token forType:type];
}

@interface RevenantPushBridge : NSObject
@end

@implementation RevenantPushBridge

+ (void)load
{
    SEL selector = @selector(setDelegate:);
    Method method = class_getInstanceMethod([UIApplication class], selector);
    if (!method)
        return;
    void (*original)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(method);
    class_replaceMethod([UIApplication class], selector, imp_implementationWithBlock(^(UIApplication *application, id<UIApplicationDelegate> delegate) {
        original(application, selector, delegate);
        if (delegate)
            [self installOnDelegateClass:[delegate class]];
    }), method_getTypeEncoding(method));
}

+ (void)installOnDelegateClass:(Class)delegateClass
{
    static NSMutableSet<NSValue *> *installed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        installed = [NSMutableSet set];
    });
    NSValue *key = [NSValue valueWithNonretainedObject:delegateClass];
    @synchronized (installed) {
        if ([installed containsObject:key])
            return;
        [installed addObject:key];
    }
    [self chainTokenSelectorOnClass:delegateClass];
    [self chainErrorSelectorOnClass:delegateClass];
}

+ (void)chainTokenSelectorOnClass:(Class)delegateClass
{
    SEL selector = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
    Method method = class_getInstanceMethod(delegateClass, selector);
    void (*original)(id, SEL, id, id) = method ? (void (*)(id, SEL, id, id))method_getImplementation(method) : NULL;
    const char *encoding = method ? method_getTypeEncoding(method) : "v@:@@";
    class_replaceMethod(delegateClass, selector, imp_implementationWithBlock(^(id self_, UIApplication *application, NSData *token) {
        if (original)
            original(self_, selector, application, token);
        RevenantPushDeliverToken(token, PKPushTypeVoIP);
    }), encoding);
}

+ (void)chainErrorSelectorOnClass:(Class)delegateClass
{
    SEL selector = @selector(application:didFailToRegisterForRemoteNotificationsWithError:);
    Method method = class_getInstanceMethod(delegateClass, selector);
    void (*original)(id, SEL, id, id) = method ? (void (*)(id, SEL, id, id))method_getImplementation(method) : NULL;
    const char *encoding = method ? method_getTypeEncoding(method) : "v@:@@";
    class_replaceMethod(delegateClass, selector, imp_implementationWithBlock(^(id self_, UIApplication *application, NSError *error) {
        if (original)
            original(self_, selector, application, error);
    }), encoding);
}

@end

@interface PKPushRegistry ()
{
    dispatch_queue_t _revenantQueue;
    NSMutableDictionary<PKPushType, NSData *> *_revenantTokens;
}
@end

@implementation PKPushRegistry

@synthesize delegate = _delegate;
@synthesize desiredPushTypes = _desiredPushTypes;

- (instancetype)init
{
    return [self initWithQueue:nil];
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue
{
    if ((self = [super init])) {
        _revenantQueue = queue ?: dispatch_get_main_queue();
        _revenantTokens = [NSMutableDictionary dictionary];
        NSHashTable *registries = RevenantActivePushRegistries();
        @synchronized (registries) {
            [registries addObject:self];
        }
    }
    return self;
}

- (void)dealloc
{
    NSHashTable *registries = RevenantActivePushRegistries();
    @synchronized (registries) {
        [registries removeObject:self];
    }
}

- (NSSet<PKPushType> *)desiredPushTypes
{
    return _desiredPushTypes;
}

- (void)setDesiredPushTypes:(NSSet<PKPushType> *)desiredPushTypes
{
    _desiredPushTypes = [desiredPushTypes copy];
    if (![desiredPushTypes containsObject:PKPushTypeVoIP])
        return;
    NSData *cached = [[NSUserDefaults standardUserDefaults] objectForKey:[RevenantPushTokenDefaultsKeyPrefix stringByAppendingString:PKPushTypeVoIP]];
    if ([cached isKindOfClass:[NSData class]])
        [self revenant_deliverToken:cached forType:PKPushTypeVoIP];
    NSUInteger types = [[[NSUserDefaults standardUserDefaults] objectForKey:RevenantRegisteredTypesKey] unsignedIntegerValue];
    if (types != 0)
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationType)types];
}

- (NSData *)pushTokenForType:(PKPushType)type
{
    @synchronized (_revenantTokens) {
        return _revenantTokens[type];
    }
}

- (void)revenant_deliverToken:(NSData *)token forType:(PKPushType)type
{
    if (![self.desiredPushTypes containsObject:type])
        return;
    @synchronized (_revenantTokens) {
        if ([_revenantTokens[type] isEqualToData:token])
            return;
        _revenantTokens[type] = token;
    }
    PKPushCredentials *credentials = [[PKPushCredentials alloc] initWithRevenantType:type token:token];
    id<PKPushRegistryDelegate> delegate = self.delegate;
    dispatch_async(_revenantQueue, ^{
        if ([delegate respondsToSelector:@selector(pushRegistry:didUpdatePushCredentials:forType:)])
            [delegate pushRegistry:self didUpdatePushCredentials:credentials forType:type];
    });
}

@end
