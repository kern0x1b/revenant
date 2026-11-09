#if defined(REVENANT_HOST_BUILD)
#define INIntentResolutionResult INIntentResolutionResultRevenant
#define INPersonResolutionResult INPersonResolutionResultRevenant
#define INStringResolutionResult INStringResolutionResultRevenant
#define INMessageAttributeResolutionResult INMessageAttributeResolutionResultRevenant
#define INMessageAttributeOptionsResolutionResult INMessageAttributeOptionsResolutionResultRevenant
#define INSendMessageRecipientResolutionResult INSendMessageRecipientResolutionResultRevenant
#define INStartCallContactResolutionResult INStartCallContactResolutionResultRevenant
#define INCallDestinationTypeResolutionResult INCallDestinationTypeResolutionResultRevenant
#define INCallRecordTypeResolutionResult INCallRecordTypeResolutionResultRevenant
#define INCallRecordTypeOptionsResolutionResult INCallRecordTypeOptionsResolutionResultRevenant
#endif

#import <Intents/Intents.h>
#import <Intents/INPersonResolutionResult.h>
#import <Intents/INStringResolutionResult.h>
#import <Intents/INMessageAttributeResolutionResult.h>
#import <Intents/INMessageAttributeOptionsResolutionResult.h>
#import <Intents/INSendMessageRecipientResolutionResult.h>
#import <Intents/INStartCallContactResolutionResult.h>
#import <Intents/INCallDestinationTypeResolutionResult.h>
#import <Intents/INCallRecordTypeResolutionResult.h>
#import <Intents/INCallRecordTypeOptionsResolutionResult.h>

#import "coding/RevenantCoding.h"
#import "RevenantIntentsResolution.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *revenant_reason_description(NSString *base, NSString *reason)
{
    return [[base substringToIndex:base.length - 1] stringByAppendingFormat:@" reason=%@>", reason];
}

static NSString *revenant_recipient_reason_name(INSendMessageRecipientUnsupportedReason reason)
{
    switch (reason) {
        case INSendMessageRecipientUnsupportedReasonNoAccount:
            return @"noAccount";
        case INSendMessageRecipientUnsupportedReasonOffline:
            return @"offline";
        case INSendMessageRecipientUnsupportedReasonMessagingServiceNotEnabledForRecipient:
            return @"messagingServiceNotEnabledForRecipient";
        case INSendMessageRecipientUnsupportedReasonNoValidHandle:
            return @"noValidHandle";
        case INSendMessageRecipientUnsupportedReasonRequestedHandleInvalid:
            return @"requestedHandleInvalid";
        case INSendMessageRecipientUnsupportedReasonNoHandleForLabel:
            return @"noHandleForLabel";
        case INSendMessageRecipientUnsupportedReasonRequiringInAppAuthentication:
            return @"requiringInAppAuthentication";
    }
    return [NSString stringWithFormat:@"%ld", (long)reason];
}

static NSString *revenant_contact_reason_name(INStartCallContactUnsupportedReason reason)
{
    switch (reason) {
        case INStartCallContactUnsupportedReasonNoContactFound:
            return @"noContactFound";
        case INStartCallContactUnsupportedReasonMultipleContactsUnsupported:
            return @"multipleContactsUnsupported";
        case INStartCallContactUnsupportedReasonNoHandleForLabel:
            return @"noHandleForLabel";
        case INStartCallContactUnsupportedReasonInvalidHandle:
            return @"invalidHandle";
        case INStartCallContactUnsupportedReasonUnsupportedMmiUssd:
            return @"unsupportedMmiUssd";
        case INStartCallContactUnsupportedReasonNoCallHistoryForRedial:
            return @"noCallHistoryForRedial";
        case INStartCallContactUnsupportedReasonNoUsableHandleForRedial:
            return @"noUsableHandleForRedial";
        case INStartCallContactUnsupportedReasonRequiringInAppAuthentication:
            return @"requiringInAppAuthentication";
    }
    return [NSString stringWithFormat:@"%ld", (long)reason];
}

#pragma mark - INPersonResolutionResult

@implementation INPersonResolutionResult

+ (instancetype)successWithResolvedPerson:(INPerson *)resolvedPerson
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionSuccess
                                 resolvedValue:resolvedPerson
                          valuesToDisambiguate:nil
                                valueToConfirm:nil];
}

+ (instancetype)disambiguationWithPeopleToDisambiguate:(NSArray<INPerson *> *)peopleToDisambiguate
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionDisambiguation
                                 resolvedValue:nil
                          valuesToDisambiguate:peopleToDisambiguate
                                valueToConfirm:nil];
}

+ (instancetype)confirmationRequiredWithPersonToConfirm:(INPerson *)personToConfirm
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionConfirmationRequired
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:personToConfirm];
}

@end

#pragma mark - INSendMessageRecipientResolutionResult

@implementation INSendMessageRecipientResolutionResult

+ (instancetype)unsupportedForReason:(INSendMessageRecipientUnsupportedReason)reason
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionUnsupported
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:nil
                             unsupportedReason:reason];
}

- (instancetype)initWithPersonResolutionResult:(INPersonResolutionResult *)personResolutionResult
{
    if ((self = revenant_intents_super_init(self, [INIntentResolutionResult class])))
        [self revenant_adoptResolutionOf:personResolutionResult];
    return self;
}

- (NSString *)description
{
    NSString *base = [super description];
    NSInteger reason = [self revenant_unsupportedReason];
    return reason ? revenant_reason_description(base, revenant_recipient_reason_name((INSendMessageRecipientUnsupportedReason)reason)) : base;
}

@end

#pragma mark - INStartCallContactResolutionResult

@implementation INStartCallContactResolutionResult

+ (instancetype)unsupportedForReason:(INStartCallContactUnsupportedReason)reason
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionUnsupported
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:nil
                             unsupportedReason:reason];
}

- (instancetype)initWithPersonResolutionResult:(INPersonResolutionResult *)personResolutionResult
{
    if ((self = revenant_intents_super_init(self, [INIntentResolutionResult class])))
        [self revenant_adoptResolutionOf:personResolutionResult];
    return self;
}

- (NSString *)description
{
    NSString *base = [super description];
    NSInteger reason = [self revenant_unsupportedReason];
    return reason ? revenant_reason_description(base, revenant_contact_reason_name((INStartCallContactUnsupportedReason)reason)) : base;
}

@end

#pragma mark - INStringResolutionResult

@implementation INStringResolutionResult

+ (instancetype)successWithResolvedString:(NSString *)resolvedString
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionSuccess
                                 resolvedValue:resolvedString
                          valuesToDisambiguate:nil
                                valueToConfirm:nil];
}

+ (instancetype)disambiguationWithStringsToDisambiguate:(NSArray<NSString *> *)stringsToDisambiguate
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionDisambiguation
                                 resolvedValue:nil
                          valuesToDisambiguate:stringsToDisambiguate
                                valueToConfirm:nil];
}

+ (instancetype)confirmationRequiredWithStringToConfirm:(NSString *)stringToConfirm
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionConfirmationRequired
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:stringToConfirm];
}

@end

#pragma mark - INMessageAttributeResolutionResult

@implementation INMessageAttributeResolutionResult

+ (instancetype)successWithResolvedMessageAttribute:(INMessageAttribute)resolvedMessageAttribute
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionSuccess
                                 resolvedValue:@(resolvedMessageAttribute)
                          valuesToDisambiguate:nil
                                valueToConfirm:nil];
}

+ (instancetype)successWithResolvedValue:(INMessageAttribute)resolvedValue
{
    return [self successWithResolvedMessageAttribute:resolvedValue];
}

+ (instancetype)confirmationRequiredWithMessageAttributeToConfirm:(INMessageAttribute)messageAttributeToConfirm
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionConfirmationRequired
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:@(messageAttributeToConfirm)];
}

+ (instancetype)confirmationRequiredWithValueToConfirm:(INMessageAttribute)valueToConfirm
{
    return [self confirmationRequiredWithMessageAttributeToConfirm:valueToConfirm];
}

@end

#pragma mark - INMessageAttributeOptionsResolutionResult

@implementation INMessageAttributeOptionsResolutionResult

+ (instancetype)successWithResolvedMessageAttributeOptions:(INMessageAttributeOptions)resolvedMessageAttributeOptions
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionSuccess
                                 resolvedValue:@(resolvedMessageAttributeOptions)
                          valuesToDisambiguate:nil
                                valueToConfirm:nil];
}

+ (instancetype)successWithResolvedValue:(INMessageAttributeOptions)resolvedValue
{
    return [self successWithResolvedMessageAttributeOptions:resolvedValue];
}

+ (instancetype)confirmationRequiredWithMessageAttributeOptionsToConfirm:(INMessageAttributeOptions)messageAttributeOptionsToConfirm
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionConfirmationRequired
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:@(messageAttributeOptionsToConfirm)];
}

+ (instancetype)confirmationRequiredWithValueToConfirm:(INMessageAttributeOptions)valueToConfirm
{
    return [self confirmationRequiredWithMessageAttributeOptionsToConfirm:valueToConfirm];
}

@end

#pragma mark - INCallDestinationTypeResolutionResult

@implementation INCallDestinationTypeResolutionResult

+ (instancetype)successWithResolvedCallDestinationType:(INCallDestinationType)resolvedCallDestinationType
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionSuccess
                                 resolvedValue:@(resolvedCallDestinationType)
                          valuesToDisambiguate:nil
                                valueToConfirm:nil];
}

+ (instancetype)confirmationRequiredWithCallDestinationTypeToConfirm:(INCallDestinationType)callDestinationTypeToConfirm
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionConfirmationRequired
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:@(callDestinationTypeToConfirm)];
}

@end

#pragma mark - INCallRecordTypeResolutionResult

@implementation INCallRecordTypeResolutionResult

+ (instancetype)successWithResolvedCallRecordType:(INCallRecordType)resolvedCallRecordType
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionSuccess
                                 resolvedValue:@(resolvedCallRecordType)
                          valuesToDisambiguate:nil
                                valueToConfirm:nil];
}

+ (instancetype)confirmationRequiredWithCallRecordTypeToConfirm:(INCallRecordType)callRecordTypeToConfirm
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionConfirmationRequired
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:@(callRecordTypeToConfirm)];
}

@end

#pragma mark - INCallRecordTypeOptionsResolutionResult

@implementation INCallRecordTypeOptionsResolutionResult

+ (instancetype)successWithResolvedCallRecordTypeOptions:(INCallRecordTypeOptions)resolvedCallRecordTypeOptions
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionSuccess
                                 resolvedValue:@(resolvedCallRecordTypeOptions)
                          valuesToDisambiguate:nil
                                valueToConfirm:nil];
}

+ (instancetype)confirmationRequiredWithCallRecordTypeOptionsToConfirm:(INCallRecordTypeOptions)callRecordTypeOptionsToConfirm
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionConfirmationRequired
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:@(callRecordTypeOptionsToConfirm)];
}

@end
