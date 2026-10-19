#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef id (^CharonUserInfoValueProvider)(NSError *error, NSErrorUserInfoKey key);

static NSMutableDictionary *charon_providers(void)
{
    static NSMutableDictionary *providers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ providers = [NSMutableDictionary dictionary]; });
    return providers;
}

static id charon_provided(NSError *error, NSErrorUserInfoKey key)
{
    if ([error.userInfo objectForKey:key])
        return nil;
    CharonUserInfoValueProvider provider;
    @synchronized(charon_providers()) {
        provider = charon_providers()[error.domain];
    }
    return provider ? provider(error, key) : nil;
}

@implementation NSError (CharonUserInfoValueProvider)

+ (void)setUserInfoValueProviderForDomain:(NSErrorDomain)errorDomain provider:(id (^)(NSError *err, NSErrorUserInfoKey userInfoKey))provider
{
    if (!errorDomain)
        return;
    @synchronized(charon_providers()) {
        if (provider)
            charon_providers()[errorDomain] = [provider copy];
        else
            [charon_providers() removeObjectForKey:errorDomain];
    }
}

+ (id (^)(NSError *, NSErrorUserInfoKey))userInfoValueProviderForDomain:(NSErrorDomain)errorDomain
{
    if (!errorDomain)
        return nil;
    id provider;
    @synchronized(charon_providers()) {
        provider = charon_providers()[errorDomain];
    }
    return provider;
}

- (NSString *)localizedDescription
{
    return charon_provided(self, NSLocalizedDescriptionKey) ?: [NSString stringWithFormat:@"%@ %ld", self.domain, (long)self.code];
}

- (NSString *)localizedFailureReason
{
    return charon_provided(self, NSLocalizedFailureReasonErrorKey);
}

- (NSString *)localizedRecoverySuggestion
{
    return charon_provided(self, NSLocalizedRecoverySuggestionErrorKey);
}

- (NSArray *)localizedRecoveryOptions
{
    return charon_provided(self, NSLocalizedRecoveryOptionsErrorKey);
}

- (id)recoveryAttempter
{
    return charon_provided(self, NSRecoveryAttempterErrorKey);
}

- (NSString *)helpAnchor
{
    return charon_provided(self, NSHelpAnchorErrorKey);
}

@end

/* The install of the six methods the provider answers, on the class it is given. Every one of them is NSError's
   own since 10.0, so a category's copy of it is never attached (attach.c adds a category's method only where
   the class does not answer the selector) and this is what puts the provider in front of the release's own
   method. +load below calls it with NSError itself, where the method being replaced is the release's own; a
   host differential calls it with a class of its own, because a host's Foundation has carried the provider
   API since 10.11 and its +load returns without touching anything. class_replaceMethod covers both: it
   replaces the method where the class has one and adds it where the class only inherits it. */
void charon_install_user_info_value_provider(Class cls)
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
            id value = charon_provided(self_, key);
            if (value)
                return value;
            if (description && ![self_.userInfo objectForKey:NSLocalizedFailureReasonErrorKey]) {
                NSString *reason = charon_provided(self_, NSLocalizedFailureReasonErrorKey);
                if (reason) {
                    NSError *composed = [NSError errorWithDomain:self_.domain code:self_.code userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
                    return original(composed, selector);
                }
            }
            return original(self_, selector);
        }), method_getTypeEncoding(method));
    }
}

@interface CharonErrorProviderInstaller : NSObject
@end

@implementation CharonErrorProviderInstaller

/* The release decides, and the release alone: +load runs before attach.c's constructor attaches the library's
   own categories, so what answers +setUserInfoValueProviderForDomain:provider: here is what iOS 9.0 and
   later have of their own and what the releases before do not. The provider's API is 9.0. */
+ (void)load
{
    if ([NSError respondsToSelector:@selector(setUserInfoValueProviderForDomain:provider:)])
        return;
    charon_install_user_info_value_provider([NSError class]);
}

@end
