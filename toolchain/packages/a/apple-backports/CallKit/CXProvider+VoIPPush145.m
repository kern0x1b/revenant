#import <CallKit/CallKit.h>

@implementation CXProvider (CharonVoIPPush)

+ (void)reportNewIncomingVoIPPushPayload:(NSDictionary *)dictionaryPayload completion:(void (^)(NSError *error))completion
{
    if (completion)
        completion([NSError errorWithDomain:CXErrorDomainNotificationServiceExtension
                                       code:CXErrorCodeNotificationServiceExtensionErrorMissingNotificationFilteringEntitlement
                                   userInfo:nil]);
}

@end
