#import <Intents/Intents.h>
#import <Intents/INStartCallIntent.h>

#import "RevenantCoding.h"

@implementation INStartCallIntent {
    INCallRecordFilter *_callRecordFilter;
    INCallRecord *_callRecordToCallBack;
    INCallAudioRoute _audioRoute;
    INCallDestinationType _destinationType;
    NSArray<INPerson *> *_contacts;
    INCallCapability _callCapability;
}

@synthesize callRecordFilter = _callRecordFilter;
@synthesize callRecordToCallBack = _callRecordToCallBack;
@synthesize audioRoute = _audioRoute;
@synthesize destinationType = _destinationType;
@synthesize contacts = _contacts;
@synthesize callCapability = _callCapability;

- (instancetype)initWithCallRecordFilter:(INCallRecordFilter *)callRecordFilter
                    callRecordToCallBack:(INCallRecord *)callRecordToCallBack
                              audioRoute:(INCallAudioRoute)audioRoute
                         destinationType:(INCallDestinationType)destinationType
                                contacts:(NSArray<INPerson *> *)contacts
                          callCapability:(INCallCapability)callCapability
{
    if ((self = [super init])) {
        _callRecordFilter = [callRecordFilter copy];
        _callRecordToCallBack = [callRecordToCallBack copy];
        _audioRoute = audioRoute;
        _destinationType = destinationType;
        _contacts = [contacts copy];
        _callCapability = callCapability;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithCallRecordFilter:nil callRecordToCallBack:nil audioRoute:INCallAudioRouteUnknown destinationType:INCallDestinationTypeUnknown contacts:nil callCapability:INCallCapabilityUnknown];
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
    INStartCallIntent *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    INStartCallIntent *other = object;
    return ((_callRecordFilter == other.callRecordFilter) || [_callRecordFilter isEqual:other.callRecordFilter]) &&
        ((_callRecordToCallBack == other.callRecordToCallBack) || [_callRecordToCallBack isEqual:other.callRecordToCallBack]) &&
        _audioRoute == other.audioRoute && _destinationType == other.destinationType &&
        ((_contacts == other.contacts) || [_contacts isEqualToArray:other.contacts]) &&
        _callCapability == other.callCapability;
}

- (NSUInteger)hash
{
    return _contacts.hash ^ ((NSUInteger)_audioRoute << 1) ^ ((NSUInteger)_destinationType << 2) ^ ((NSUInteger)_callCapability << 3);
}

@end
