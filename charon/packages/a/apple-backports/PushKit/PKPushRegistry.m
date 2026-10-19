#import <PushKit/PushKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PKPushCredentials (CharonPushKit)
- (instancetype)initWithCharonType:(PKPushType)type token:(NSData *)token;
@end

static NSString *const CharonPushTokenDefaultsKeyPrefix = @"org.charon.apple-backports.PKPushToken.";
static NSString *const CharonRegisteredTypesKey = @"org.charon.apple-backports.UIUserNotificationTypes";

@interface PKPushRegistry (CharonPushKit)
- (void)charon_deliverToken:(NSData *)token forType:(PKPushType)type;
@end

static NSHashTable<PKPushRegistry *> *CharonActivePushRegistries(void)
{
    static NSHashTable<PKPushRegistry *> *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSHashTable weakObjectsHashTable];
    });
    return table;
}

static void CharonPushDeliverToken(NSData *token, PKPushType type)
{
    if (!token || !type)
        return;
    [[NSUserDefaults standardUserDefaults] setObject:token forKey:[CharonPushTokenDefaultsKeyPrefix stringByAppendingString:type]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSHashTable *registries = CharonActivePushRegistries();
    NSArray<PKPushRegistry *> *snapshot;
    @synchronized (registries) {
        snapshot = registries.allObjects;
    }
    for (PKPushRegistry *registry in snapshot)
        [registry charon_deliverToken:token forType:type];
}

@interface CharonPushBridge : NSObject
@end

@implementation CharonPushBridge

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
        CharonPushDeliverToken(token, PKPushTypeVoIP);
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
    dispatch_queue_t _charonQueue;
    NSMutableDictionary<PKPushType, NSData *> *_charonTokens;
}
@end

@implementation PKPushRegistry

@synthesize delegate = _delegate;
@synthesize desiredPushTypes = _desiredPushTypes;

// The header marks -init unavailable and names -initWithQueue: as the designated initialiser, with
// nil documented to mean the main queue. There is no other way to make a registry, so a caller that
// reaches it anyway gets a registry whose queue is the main queue, which is what the header's own
// nil says - the same answer the port gives +[UICollectionViewDiffableDataSource new], whose -init
// the header also marks unavailable.
- (instancetype)init
{
    return [self initWithQueue:nil];
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue
{
    if ((self = [super init])) {
        _charonQueue = queue ?: dispatch_get_main_queue();
        _charonTokens = [NSMutableDictionary dictionary];
        NSHashTable *registries = CharonActivePushRegistries();
        @synchronized (registries) {
            [registries addObject:self];
        }
    }
    return self;
}

- (void)dealloc
{
    NSHashTable *registries = CharonActivePushRegistries();
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
    NSData *cached = [[NSUserDefaults standardUserDefaults] objectForKey:[CharonPushTokenDefaultsKeyPrefix stringByAppendingString:PKPushTypeVoIP]];
    if ([cached isKindOfClass:[NSData class]])
        [self charon_deliverToken:cached forType:PKPushTypeVoIP];
    NSUInteger types = [[[NSUserDefaults standardUserDefaults] objectForKey:CharonRegisteredTypesKey] unsignedIntegerValue];
    if (types != 0)
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationType)types];
}

- (NSData *)pushTokenForType:(PKPushType)type
{
    @synchronized (_charonTokens) {
        return _charonTokens[type];
    }
}

- (void)charon_deliverToken:(NSData *)token forType:(PKPushType)type
{
    if (![self.desiredPushTypes containsObject:type])
        return;
    @synchronized (_charonTokens) {
        if ([_charonTokens[type] isEqualToData:token])
            return;
        _charonTokens[type] = token;
    }
    PKPushCredentials *credentials = [[PKPushCredentials alloc] initWithCharonType:type token:token];
    id<PKPushRegistryDelegate> delegate = self.delegate;
    dispatch_async(_charonQueue, ^{
        if ([delegate respondsToSelector:@selector(pushRegistry:didUpdatePushCredentials:forType:)])
            [delegate pushRegistry:self didUpdatePushCredentials:credentials forType:type];
    });
}

@end
