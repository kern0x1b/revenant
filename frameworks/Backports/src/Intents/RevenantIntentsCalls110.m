#if defined(REVENANT_HOST_BUILD)
#define INCallRecord INCallRecordRevenant
#define INSearchCallHistoryIntent INSearchCallHistoryIntentRevenant
#define REVENANT_INTENT_SUPER_INIT(self) revenant_intents_super_init(self, [NSObject class])
#else
#define REVENANT_INTENT_SUPER_INIT(self) [super init]
#endif

#import <Intents/Intents.h>
#import <Intents/INCallRecord.h>
#import <Intents/INCallRecord_Deprecated.h>
#import <Intents/INCallRecordType.h>
#import <Intents/INCallRecordTypeOptions.h>
#import <Intents/INCallCapability.h>
#import <Intents/INCallCapabilityOptions.h>
#import <Intents/INSearchCallHistoryIntent.h>
#import <Intents/INSearchCallHistoryIntent_Deprecated.h>

#import "coding/RevenantCoding.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static INCallRecordTypeOptions revenant_call_type_option(INCallRecordType type)
{
    switch (type) {
        case INCallRecordTypeOutgoing:
            return INCallRecordTypeOptionOutgoing;
        case INCallRecordTypeMissed:
            return INCallRecordTypeOptionMissed;
        case INCallRecordTypeReceived:
            return INCallRecordTypeOptionReceived;
        case INCallRecordTypeLatest:
            return INCallRecordTypeOptionLatest;
        case INCallRecordTypeVoicemail:
            return INCallRecordTypeOptionVoicemail;
        case INCallRecordTypeRinging:
            return INCallRecordTypeOptionRinging;
        case INCallRecordTypeInProgress:
            return INCallRecordTypeOptionInProgress;
        case INCallRecordTypeOnHold:
            return INCallRecordTypeOptionOnHold;
        case INCallRecordTypeUnknown:
            break;
    }
    return 0;
}

static INCallRecordType revenant_call_type_of_option(INCallRecordTypeOptions options)
{
    switch (options) {
        case INCallRecordTypeOptionOutgoing:
            return INCallRecordTypeOutgoing;
        case INCallRecordTypeOptionMissed:
            return INCallRecordTypeMissed;
        case INCallRecordTypeOptionReceived:
            return INCallRecordTypeReceived;
        case INCallRecordTypeOptionLatest:
            return INCallRecordTypeLatest;
        case INCallRecordTypeOptionVoicemail:
            return INCallRecordTypeVoicemail;
        case INCallRecordTypeOptionRinging:
            return INCallRecordTypeRinging;
        case INCallRecordTypeOptionInProgress:
            return INCallRecordTypeInProgress;
        case INCallRecordTypeOptionOnHold:
            return INCallRecordTypeOnHold;
    }
    return INCallRecordTypeUnknown;
}

#pragma mark - INCallRecord

@implementation INCallRecord {
    NSString *_identifier;
    NSDate *_dateCreated;
    INCallRecordType _callRecordType;
    INCallCapability _callCapability;
    NSNumber *_callDuration;
    NSNumber *_unseen;
    NSArray<INPerson *> *_participants;
    NSNumber *_numberOfCalls;
    NSNumber *_isCallerIdBlocked;
}

@synthesize identifier = _identifier;
@synthesize dateCreated = _dateCreated;
@synthesize callRecordType = _callRecordType;
@synthesize callCapability = _callCapability;
@synthesize callDuration = _callDuration;
@synthesize unseen = _unseen;
@synthesize participants = _participants;
@synthesize numberOfCalls = _numberOfCalls;
@synthesize isCallerIdBlocked = _isCallerIdBlocked;

- (instancetype)initWithIdentifier:(NSString *)identifier
                       dateCreated:(NSDate *)dateCreated
                    callRecordType:(INCallRecordType)callRecordType
                    callCapability:(INCallCapability)callCapability
                      callDuration:(NSNumber *)callDuration
                            unseen:(NSNumber *)unseen
                      participants:(NSArray<INPerson *> *)participants
                     numberOfCalls:(NSNumber *)numberOfCalls
                 isCallerIdBlocked:(NSNumber *)isCallerIdBlocked
{
    if ((self = REVENANT_INTENT_SUPER_INIT(self))) {
        _identifier = [identifier copy];
        _dateCreated = [dateCreated copy];
        _callRecordType = callRecordType;
        _callCapability = callCapability;
        _callDuration = [callDuration copy];
        _unseen = [unseen copy];
        _participants = [participants copy];
        _numberOfCalls = [numberOfCalls copy];
        _isCallerIdBlocked = [isCallerIdBlocked copy];
    }
    return self;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                       dateCreated:(NSDate *)dateCreated
                    callRecordType:(INCallRecordType)callRecordType
                    callCapability:(INCallCapability)callCapability
                      callDuration:(NSNumber *)callDuration
                            unseen:(NSNumber *)unseen
                     numberOfCalls:(NSNumber *)numberOfCalls
{
    return [self initWithIdentifier:identifier dateCreated:dateCreated callRecordType:callRecordType callCapability:callCapability
                       callDuration:callDuration unseen:unseen participants:nil numberOfCalls:numberOfCalls isCallerIdBlocked:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                       dateCreated:(NSDate *)dateCreated
                    callRecordType:(INCallRecordType)callRecordType
                    callCapability:(INCallCapability)callCapability
                      callDuration:(NSNumber *)callDuration
                            unseen:(NSNumber *)unseen
{
    return [self initWithIdentifier:identifier dateCreated:dateCreated callRecordType:callRecordType callCapability:callCapability
                       callDuration:callDuration unseen:unseen participants:nil numberOfCalls:nil isCallerIdBlocked:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                       dateCreated:(NSDate *)dateCreated
                            caller:(INPerson *)caller
                    callRecordType:(INCallRecordType)callRecordType
                    callCapability:(INCallCapability)callCapability
                      callDuration:(NSNumber *)callDuration
                            unseen:(NSNumber *)unseen
                     numberOfCalls:(NSNumber *)numberOfCalls
{
    return [self initWithIdentifier:identifier dateCreated:dateCreated callRecordType:callRecordType callCapability:callCapability
                       callDuration:callDuration unseen:unseen participants:caller ? @[caller] : nil numberOfCalls:numberOfCalls
                  isCallerIdBlocked:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                       dateCreated:(NSDate *)dateCreated
                            caller:(INPerson *)caller
                    callRecordType:(INCallRecordType)callRecordType
                    callCapability:(INCallCapability)callCapability
                      callDuration:(NSNumber *)callDuration
                            unseen:(NSNumber *)unseen
{
    return [self initWithIdentifier:identifier dateCreated:dateCreated callRecordType:callRecordType callCapability:callCapability
                       callDuration:callDuration unseen:unseen participants:caller ? @[caller] : nil numberOfCalls:nil
                  isCallerIdBlocked:nil];
}

- (INPerson *)caller
{
    return _participants.firstObject;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self initWithIdentifier:@"" dateCreated:nil callRecordType:INCallRecordTypeUnknown callCapability:INCallCapabilityUnknown
                            callDuration:nil unseen:nil participants:nil numberOfCalls:nil isCallerIdBlocked:nil]))
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithIdentifier:_identifier dateCreated:_dateCreated callRecordType:_callRecordType
                                                  callCapability:_callCapability callDuration:_callDuration unseen:_unseen
                                                    participants:_participants numberOfCalls:_numberOfCalls
                                               isCallerIdBlocked:_isCallerIdBlocked];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    return revenant_intents_equal(self, object, [INCallRecord class]);
}

- (NSUInteger)hash
{
    return revenant_intents_hash(self, [INCallRecord class]);
}

@end

#pragma mark - INSearchCallHistoryIntent

@implementation INSearchCallHistoryIntent {
    INDateComponentsRange *_dateCreated;
    INPerson *_recipient;
    INCallCapabilityOptions _callCapabilities;
    INCallRecordTypeOptions _callTypes;
    NSNumber *_unseen;
}

@synthesize dateCreated = _dateCreated;
@synthesize recipient = _recipient;
@synthesize callCapabilities = _callCapabilities;
@synthesize callTypes = _callTypes;
@synthesize unseen = _unseen;

- (instancetype)initWithDateCreated:(INDateComponentsRange *)dateCreated
                          recipient:(INPerson *)recipient
                   callCapabilities:(INCallCapabilityOptions)callCapabilities
                          callTypes:(INCallRecordTypeOptions)callTypes
                             unseen:(NSNumber *)unseen
{
    if ((self = REVENANT_INTENT_SUPER_INIT(self))) {
        _dateCreated = [dateCreated copy];
        _recipient = [recipient copy];
        _callCapabilities = callCapabilities;
        _callTypes = callTypes;
        _unseen = [unseen copy];
    }
    return self;
}

- (instancetype)initWithCallType:(INCallRecordType)callType
                     dateCreated:(INDateComponentsRange *)dateCreated
                       recipient:(INPerson *)recipient
                callCapabilities:(INCallCapabilityOptions)callCapabilities
{
    return [self initWithDateCreated:dateCreated recipient:recipient callCapabilities:callCapabilities
                           callTypes:revenant_call_type_option(callType) unseen:nil];
}

- (instancetype)init
{
    return [self initWithDateCreated:nil recipient:nil callCapabilities:0 callTypes:0 unseen:nil];
}

- (INCallRecordType)callType
{
    return revenant_call_type_of_option(_callTypes);
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init]))
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INSearchCallHistoryIntent *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    return revenant_intents_equal(self, object, [INSearchCallHistoryIntent class]);
}

- (NSUInteger)hash
{
    return revenant_intents_hash(self, [INSearchCallHistoryIntent class]);
}

@end
