#import <CallKit/CallKit.h>

// The header gives the method to a Notification Service Extension, to have its application launched for a VoIP call.
// iOS 6 has no application extensions, so no caller is ever one. The answer is the host's to a process that is not
// one and holds no notification filtering entitlement (Mac Catalyst, 2026-09-24): the completion is called once, before
// the method returns, on the caller's thread, with CXErrorDomainNotificationServiceExtension /
// MissingNotificationFilteringEntitlement and no user info. A category of its own, so a release with the class and
// without the method gets it too.
@implementation CXProvider (CharonVoIPPush)

+ (void)reportNewIncomingVoIPPushPayload:(NSDictionary *)dictionaryPayload completion:(void (^)(NSError *error))completion
{
    if (completion)
        completion([NSError errorWithDomain:CXErrorDomainNotificationServiceExtension
                                       code:CXErrorCodeNotificationServiceExtensionErrorMissingNotificationFilteringEntitlement
                                   userInfo:nil]);
}

@end
