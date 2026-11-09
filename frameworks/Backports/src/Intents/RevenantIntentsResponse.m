#if defined(REVENANT_HOST_BUILD)
#define INIntentResponse INIntentResponseRevenant
#define INSendMessageIntentResponse INSendMessageIntentResponseRevenant
#define INSearchForMessagesIntentResponse INSearchForMessagesIntentResponseRevenant
#define INSetMessageAttributeIntentResponse INSetMessageAttributeIntentResponseRevenant
#define INSearchCallHistoryIntentResponse INSearchCallHistoryIntentResponseRevenant
#define INStartCallIntentResponse INStartCallIntentResponseRevenant
#endif

#import <Intents/Intents.h>
#import <Intents/INIntentResponse.h>
#import <Intents/INSendMessageIntentResponse.h>
#import <Intents/INSearchForMessagesIntentResponse.h>
#import <Intents/INSetMessageAttributeIntentResponse.h>
#import <Intents/INSearchCallHistoryIntentResponse.h>
#import <Intents/INStartCallIntentResponse.h>

#import "coding/RevenantCoding.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *revenant_response_code_name(NSString *const *names, NSUInteger count, NSInteger code)
{
    NSString *name = code >= 0 && (NSUInteger)code < count ? names[code] : nil;
    return name ?: [NSString stringWithFormat:@"%ld", (long)code];
}

static NSString *revenant_response_description(INIntentResponse *response, NSString *code)
{
    return [NSString stringWithFormat:@"<%@: %p code=%@ userActivity=%@>", NSStringFromClass([response class]), response, code, response.userActivity];
}

#pragma mark - INIntentResponse

@implementation INIntentResponse {
    NSUserActivity *_userActivity;
}

- (NSUserActivity *)userActivity
{
    return _userActivity;
}

- (void)setUserActivity:(NSUserActivity *)userActivity
{
    _userActivity = [userActivity conformsToProtocol:@protocol(NSCopying)] ? [userActivity copy] : userActivity;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INIntentResponse *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

@end

#pragma mark - INSendMessageIntentResponse

@implementation INSendMessageIntentResponse {
    INSendMessageIntentResponseCode _code;
    NSArray<INMessage *> *_sentMessages;
}

@synthesize code = _code;
@synthesize sentMessages = _sentMessages;

- (instancetype)initWithCode:(INSendMessageIntentResponseCode)code userActivity:(NSUserActivity *)userActivity
{
    if ((self = [super init])) {
        _code = code;
        self.userActivity = userActivity;
    }
    return self;
}

- (NSString *)description
{
    static NSString *const names[] = {
        [INSendMessageIntentResponseCodeUnspecified] = @"unspecified",
        [INSendMessageIntentResponseCodeReady] = @"ready",
        [INSendMessageIntentResponseCodeInProgress] = @"inProgress",
        [INSendMessageIntentResponseCodeSuccess] = @"success",
        [INSendMessageIntentResponseCodeFailure] = @"failure",
        [INSendMessageIntentResponseCodeFailureRequiringAppLaunch] = @"failureRequiringAppLaunch",
        [INSendMessageIntentResponseCodeFailureMessageServiceNotAvailable] = @"failureMessageServiceNotAvailable",
        [INSendMessageIntentResponseCodeFailureRequiringInAppAuthentication] = @"failureRequiringInAppAuthentication",
    };
    return revenant_response_description(self, revenant_response_code_name(names, sizeof names / sizeof *names, _code));
}

@end

#pragma mark - INSearchForMessagesIntentResponse

@implementation INSearchForMessagesIntentResponse {
    INSearchForMessagesIntentResponseCode _code;
    NSArray<INMessage *> *_messages;
}

@synthesize code = _code;
@synthesize messages = _messages;

- (instancetype)initWithCode:(INSearchForMessagesIntentResponseCode)code userActivity:(NSUserActivity *)userActivity
{
    if ((self = [super init])) {
        _code = code;
        self.userActivity = userActivity;
    }
    return self;
}

- (NSString *)description
{
    static NSString *const names[] = {
        [INSearchForMessagesIntentResponseCodeUnspecified] = @"unspecified",
        [INSearchForMessagesIntentResponseCodeReady] = @"ready",
        [INSearchForMessagesIntentResponseCodeInProgress] = @"inProgress",
        [INSearchForMessagesIntentResponseCodeSuccess] = @"success",
        [INSearchForMessagesIntentResponseCodeFailure] = @"failure",
        [INSearchForMessagesIntentResponseCodeFailureRequiringAppLaunch] = @"failureRequiringAppLaunch",
        [INSearchForMessagesIntentResponseCodeFailureMessageServiceNotAvailable] = @"failureMessageServiceNotAvailable",
        [INSearchForMessagesIntentResponseCodeFailureMessageTooManyResults] = @"failureMessageTooManyResults",
        [INSearchForMessagesIntentResponseCodeFailureRequiringInAppAuthentication] = @"failureRequiringInAppAuthentication",
    };
    return revenant_response_description(self, revenant_response_code_name(names, sizeof names / sizeof *names, _code));
}

@end

#pragma mark - INSetMessageAttributeIntentResponse

@implementation INSetMessageAttributeIntentResponse {
    INSetMessageAttributeIntentResponseCode _code;
}

@synthesize code = _code;

- (instancetype)initWithCode:(INSetMessageAttributeIntentResponseCode)code userActivity:(NSUserActivity *)userActivity
{
    if ((self = [super init])) {
        _code = code;
        self.userActivity = userActivity;
    }
    return self;
}

- (NSString *)description
{
    static NSString *const names[] = {
        [INSetMessageAttributeIntentResponseCodeUnspecified] = @"unspecified",
        [INSetMessageAttributeIntentResponseCodeReady] = @"ready",
        [INSetMessageAttributeIntentResponseCodeInProgress] = @"inProgress",
        [INSetMessageAttributeIntentResponseCodeSuccess] = @"success",
        [INSetMessageAttributeIntentResponseCodeFailure] = @"failure",
        [INSetMessageAttributeIntentResponseCodeFailureRequiringAppLaunch] = @"failureRequiringAppLaunch",
        [INSetMessageAttributeIntentResponseCodeFailureMessageNotFound] = @"failureMessageNotFound",
        [INSetMessageAttributeIntentResponseCodeFailureMessageAttributeNotSet] = @"failureMessageAttributeNotSet",
    };
    return revenant_response_description(self, revenant_response_code_name(names, sizeof names / sizeof *names, _code));
}

@end

#pragma mark - INSearchCallHistoryIntentResponse

@implementation INSearchCallHistoryIntentResponse {
    INSearchCallHistoryIntentResponseCode _code;
    NSArray<INCallRecord *> *_callRecords;
}

@synthesize code = _code;
@synthesize callRecords = _callRecords;

- (instancetype)initWithCode:(INSearchCallHistoryIntentResponseCode)code userActivity:(NSUserActivity *)userActivity
{
    if ((self = [super init])) {
        _code = code;
        self.userActivity = userActivity;
    }
    return self;
}

- (NSString *)description
{
    static NSString *const names[] = {
        [INSearchCallHistoryIntentResponseCodeUnspecified] = @"unspecified",
        [INSearchCallHistoryIntentResponseCodeReady] = @"ready",
        [INSearchCallHistoryIntentResponseCodeContinueInApp] = @"continueInApp",
        [INSearchCallHistoryIntentResponseCodeFailure] = @"failure",
        [INSearchCallHistoryIntentResponseCodeFailureRequiringAppLaunch] = @"failureRequiringAppLaunch",
        [INSearchCallHistoryIntentResponseCodeFailureAppConfigurationRequired] = @"failureAppConfigurationRequired",
        [INSearchCallHistoryIntentResponseCodeInProgress] = @"inProgress",
        [INSearchCallHistoryIntentResponseCodeSuccess] = @"success",
    };
    return revenant_response_description(self, revenant_response_code_name(names, sizeof names / sizeof *names, _code));
}

@end

#pragma mark - INStartCallIntentResponse

@implementation INStartCallIntentResponse {
    INStartCallIntentResponseCode _code;
}

@synthesize code = _code;

- (instancetype)initWithCode:(INStartCallIntentResponseCode)code userActivity:(NSUserActivity *)userActivity
{
    if ((self = [super init])) {
        _code = code;
        self.userActivity = userActivity;
    }
    return self;
}

- (NSString *)description
{
    static NSString *const names[] = {
        [INStartCallIntentResponseCodeUnspecified] = @"unspecified",
        [INStartCallIntentResponseCodeReady] = @"ready",
        [INStartCallIntentResponseCodeContinueInApp] = @"continueInApp",
        [INStartCallIntentResponseCodeUserConfirmationRequired] = @"userConfirmationRequired",
        [INStartCallIntentResponseCodeFailure] = @"failure",
        [INStartCallIntentResponseCodeFailureRequiringAppLaunch] = @"failureRequiringAppLaunch",
        [INStartCallIntentResponseCodeFailureCallingServiceNotAvailable] = @"failureCallingServiceNotAvailable",
        [INStartCallIntentResponseCodeFailureContactNotSupportedByApp] = @"failureContactNotSupportedByApp",
        [INStartCallIntentResponseCodeFailureAirplaneModeEnabled] = @"failureAirplaneModeEnabled",
        [INStartCallIntentResponseCodeFailureUnableToHandOff] = @"failureUnableToHandOff",
        [INStartCallIntentResponseCodeFailureAppConfigurationRequired] = @"failureAppConfigurationRequired",
        [INStartCallIntentResponseCodeFailureCallInProgress] = @"failureCallInProgress",
        [INStartCallIntentResponseCodeFailureRequiringInAppAuthentication] = @"failureRequiringInAppAuthentication",
    };
    return revenant_response_description(self, revenant_response_code_name(names, sizeof names / sizeof *names, _code));
}

@end
