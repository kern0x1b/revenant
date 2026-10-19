#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef id (^RevenantUserInfoValueProvider)(NSError *error, NSErrorUserInfoKey key);

static NSMutableDictionary *revenant_providers(void)
{
    static NSMutableDictionary *providers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ providers = [NSMutableDictionary dictionary]; });
    return providers;
}

static id revenant_provided(NSError *error, NSErrorUserInfoKey key)
{
    if ([error.userInfo objectForKey:key])
        return nil;
    RevenantUserInfoValueProvider provider;
    @synchronized(revenant_providers()) {
        provider = revenant_providers()[error.domain];
    }
    return provider ? provider(error, key) : nil;
}

@implementation NSError (RevenantUserInfoValueProvider)

+ (void)setUserInfoValueProviderForDomain:(NSErrorDomain)errorDomain provider:(id (^)(NSError *err, NSErrorUserInfoKey userInfoKey))provider
{
    if (!errorDomain)
        return;
    @synchronized(revenant_providers()) {
        if (provider)
            revenant_providers()[errorDomain] = [provider copy];
        else
            [revenant_providers() removeObjectForKey:errorDomain];
    }
}

+ (id (^)(NSError *, NSErrorUserInfoKey))userInfoValueProviderForDomain:(NSErrorDomain)errorDomain
{
    if (!errorDomain)
        return nil;
    id provider;
    @synchronized(revenant_providers()) {
        provider = revenant_providers()[errorDomain];
    }
    return provider;
}

- (NSString *)localizedDescription
{
    return revenant_provided(self, NSLocalizedDescriptionKey) ?: [NSString stringWithFormat:@"%@ %ld", self.domain, (long)self.code];
}

- (NSString *)localizedFailureReason
{
    return revenant_provided(self, NSLocalizedFailureReasonErrorKey);
}

- (NSString *)localizedRecoverySuggestion
{
    return revenant_provided(self, NSLocalizedRecoverySuggestionErrorKey);
}

- (NSArray *)localizedRecoveryOptions
{
    return revenant_provided(self, NSLocalizedRecoveryOptionsErrorKey);
}

- (id)recoveryAttempter
{
    return revenant_provided(self, NSRecoveryAttempterErrorKey);
}

- (NSString *)helpAnchor
{
    return revenant_provided(self, NSHelpAnchorErrorKey);
}

@end

void revenant_install_user_info_value_provider(Class cls)
{
    NSDictionary *keys = @{
        @"localizedDescription": NSLocalizedDescriptionKey,
        @"localizedFailureReason": NSLocalizedFailureReasonErrorKey,
        @"localizedRecoverySuggestion": NSLocalizedRecoverySuggestionErrorKey,
        @"localizedRecoveryOptions": NSLocalizedRecoveryOptionsErrorKey,
        @"recoveryAttempter": NSRecoveryAttempterErrorKey,
        @"helpAnchor": NSHelpAnchorErrorKey,
    };
    for (NSString *name in keys) {
        NSErrorUserInfoKey key = keys[name];
        SEL selector = NSSelectorFromString(name);
        Method method = class_getInstanceMethod(cls, selector);
        if (!method)
            continue;
        id (*original)(id, SEL) = (id (*)(id, SEL))method_getImplementation(method);
        BOOL description = [name isEqualToString:@"localizedDescription"];
        class_replaceMethod(cls, selector, imp_implementationWithBlock(^id(NSError *self_) {
            id value = revenant_provided(self_, key);
            if (value)
                return value;
            if (description && ![self_.userInfo objectForKey:NSLocalizedFailureReasonErrorKey]) {
                NSString *reason = revenant_provided(self_, NSLocalizedFailureReasonErrorKey);
                if (reason) {
                    NSError *composed = [NSError errorWithDomain:self_.domain code:self_.code userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
                    return original(composed, selector);
                }
            }
            return original(self_, selector);
        }), method_getTypeEncoding(method));
    }
}

@interface RevenantErrorProviderInstaller : NSObject
@end

@implementation RevenantErrorProviderInstaller

+ (void)load
{
    if ([NSError respondsToSelector:@selector(setUserInfoValueProviderForDomain:provider:)])
        return;
    revenant_install_user_info_value_provider([NSError class]);
}

@end
