#import "CharonCallKit.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// CallKit gives its errors no user info at all: a caller reads the domain and
// the code, and -localizedDescription falls back to Foundation's wording for
// a domain it does not know. The port answers the same, rather than putting a
// text of its own where the release has none.
NSError *charon_callkit_error(NSString *domain, NSInteger code)
{
    return [NSError errorWithDomain:domain code:code userInfo:nil];
}

@implementation CXAction {
    NSUUID *_UUID;
    BOOL _complete;
    BOOL _charon_fulfilled;
    NSDate *_timeoutDate;
}

@dynamic UUID, complete, timeoutDate, charon_fulfilled;
@synthesize charon_provider = _charon_provider;
@synthesize charon_transaction = _charon_transaction;

// An action carries its deadline from the moment it is made, not from the
// moment it is requested: CallKit answers a timeoutDate that is already there
// before any provider has seen the action. How long it is belongs to the
// class - five seconds for most of them, ten minutes for starting a call and
// a minute for answering one, which is how long a user may take over each.
+ (NSTimeInterval)charon_timeout
{
    return 5.0;
}

- (instancetype)charon_initWithUUID:(NSUUID *)UUID
{
    if ((self = [super init])) {
        _UUID = [UUID copy];
        _timeoutDate = [NSDate dateWithTimeIntervalSinceNow:[[self class] charon_timeout]];
    }
    return self;
}

- (instancetype)init
{
    return [self charon_initWithUUID:[NSUUID UUID]];
}

- (NSUUID *)UUID
{
    return _UUID;
}

- (BOOL)isComplete
{
    return _complete;
}

- (NSDate *)timeoutDate
{
    return _timeoutDate;
}

- (void)charon_setComplete:(BOOL)complete
{
    _complete = complete;
}

- (SEL)charon_performSelector
{
    return NULL;
}

- (BOOL)charon_fulfilled
{
    return _charon_fulfilled;
}

// Fulfilling or failing an action is a message to whatever is performing it,
// and an action no provider holds has nobody to send it to: CallKit leaves
// such an action incomplete, and so does the port. Once a provider does hold
// it the action is done once - the broker reads the state off it, the
// transaction learns it finished - and a second fulfil or fail changes
// nothing.
- (void)charon_finish:(BOOL)fulfilled
{
    if (_complete || !_charon_provider)
        return;
    _complete = YES;
    _charon_fulfilled = fulfilled;
    [[CharonCallBroker shared] applyAction:self];
    [_charon_transaction charon_actionCompleted:self];
}

- (void)charon_timedOut
{
    if (_complete)
        return;
    CXProvider *provider = _charon_provider;
    [self charon_finish:NO];
    [provider charon_actionTimedOut:self];
}

- (void)fulfill
{
    [self charon_finish:YES];
}

- (void)fail
{
    [self charon_finish:NO];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p UUID=%@ complete=%@>", NSStringFromClass([self class]), self, _UUID.UUIDString, _complete ? @"YES" : @"NO"];
}

- (id)copyWithZone:(NSZone *)zone
{
    CXAction *copy = [[[self class] allocWithZone:zone] charon_initWithUUID:_UUID];
    copy->_complete = _complete;
    copy->_timeoutDate = _timeoutDate;
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_UUID forKey:@"UUID"];
    [coder encodeBool:_complete forKey:@"complete"];
    [coder encodeObject:_timeoutDate forKey:@"timeoutDate"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSUUID *UUID = [coder decodeObjectOfClass:[NSUUID class] forKey:@"UUID"];
    if (!UUID)
        return nil;
    if ((self = [self charon_initWithUUID:UUID])) {
        _complete = [coder decodeBoolForKey:@"complete"];
        _timeoutDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"timeoutDate"];
    }
    return self;
}

@end

@implementation CXCallAction {
    NSUUID *_callUUID;
}

@dynamic callUUID;
@synthesize charon_date = _charon_date;

- (instancetype)initWithCallUUID:(NSUUID *)callUUID
{
    if ((self = [self charon_initWithUUID:[NSUUID UUID]]))
        _callUUID = [callUUID copy];
    return self;
}

- (NSUUID *)callUUID
{
    return _callUUID;
}

- (void)charon_completeWithDate:(NSDate *)date
{
    if (self.isComplete)
        return;
    _charon_date = date ?: [NSDate date];
    [self fulfill];
}

- (id)copyWithZone:(NSZone *)zone
{
    CXCallAction *copy = [super copyWithZone:zone];
    copy->_callUUID = [_callUUID copy];
    copy->_charon_date = _charon_date;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_callUUID forKey:@"callUUID"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _callUUID = [[coder decodeObjectOfClass:[NSUUID class] forKey:@"callUUID"] copy];
        if (!_callUUID)
            return nil;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p UUID=%@ callUUID=%@ complete=%@>", NSStringFromClass([self class]), self,
                                      self.UUID.UUIDString, _callUUID.UUIDString, self.isComplete ? @"YES" : @"NO"];
}

@end

@implementation CXStartCallAction {
    CXHandle *_handle;
    NSString *_contactIdentifier;
    BOOL _video;
}

@dynamic handle, contactIdentifier, video;

- (instancetype)initWithCallUUID:(NSUUID *)callUUID handle:(CXHandle *)handle
{
    if ((self = [super initWithCallUUID:callUUID]))
        _handle = [handle copy];
    return self;
}

- (CXHandle *)handle
{
    return _handle;
}

- (void)setHandle:(CXHandle *)handle
{
    _handle = [handle copy];
}

- (NSString *)contactIdentifier
{
    return _contactIdentifier;
}

- (void)setContactIdentifier:(NSString *)contactIdentifier
{
    _contactIdentifier = [contactIdentifier copy];
}

- (BOOL)isVideo
{
    return _video;
}

- (void)setVideo:(BOOL)video
{
    _video = video;
}

+ (NSTimeInterval)charon_timeout
{
    return 600.0;
}

- (SEL)charon_performSelector
{
    return @selector(provider:performStartCallAction:);
}

- (void)fulfillWithDateStarted:(NSDate *)dateStarted
{
    [self charon_completeWithDate:dateStarted];
}

- (id)copyWithZone:(NSZone *)zone
{
    CXStartCallAction *copy = [super copyWithZone:zone];
    copy->_handle = [_handle copy];
    copy->_contactIdentifier = [_contactIdentifier copy];
    copy->_video = _video;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_handle forKey:@"handle"];
    [coder encodeObject:_contactIdentifier forKey:@"contactIdentifier"];
    [coder encodeBool:_video forKey:@"isVideo"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _handle = [[coder decodeObjectOfClass:[CXHandle class] forKey:@"handle"] copy];
        _contactIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"contactIdentifier"] copy];
        _video = [coder decodeBoolForKey:@"isVideo"];
    }
    return self;
}

@end

@implementation CXAnswerCallAction

+ (NSTimeInterval)charon_timeout
{
    return 60.0;
}

- (SEL)charon_performSelector
{
    return @selector(provider:performAnswerCallAction:);
}

- (void)fulfillWithDateConnected:(NSDate *)dateConnected
{
    [self charon_completeWithDate:dateConnected];
}

@end

@implementation CXEndCallAction

- (SEL)charon_performSelector
{
    return @selector(provider:performEndCallAction:);
}

- (void)fulfillWithDateEnded:(NSDate *)dateEnded
{
    [self charon_completeWithDate:dateEnded];
}

@end

@implementation CXSetHeldCallAction {
    BOOL _onHold;
}

@dynamic onHold;

- (instancetype)initWithCallUUID:(NSUUID *)callUUID onHold:(BOOL)onHold
{
    if ((self = [super initWithCallUUID:callUUID]))
        _onHold = onHold;
    return self;
}

- (BOOL)isOnHold
{
    return _onHold;
}

- (void)setOnHold:(BOOL)onHold
{
    _onHold = onHold;
}

- (SEL)charon_performSelector
{
    return @selector(provider:performSetHeldCallAction:);
}

- (id)copyWithZone:(NSZone *)zone
{
    CXSetHeldCallAction *copy = [super copyWithZone:zone];
    copy->_onHold = _onHold;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeBool:_onHold forKey:@"onHold"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        _onHold = [coder decodeBoolForKey:@"onHold"];
    return self;
}

@end

@implementation CXSetMutedCallAction {
    BOOL _muted;
}

@dynamic muted;

- (instancetype)initWithCallUUID:(NSUUID *)callUUID muted:(BOOL)muted
{
    if ((self = [super initWithCallUUID:callUUID]))
        _muted = muted;
    return self;
}

- (BOOL)isMuted
{
    return _muted;
}

- (void)setMuted:(BOOL)muted
{
    _muted = muted;
}

- (SEL)charon_performSelector
{
    return @selector(provider:performSetMutedCallAction:);
}

- (id)copyWithZone:(NSZone *)zone
{
    CXSetMutedCallAction *copy = [super copyWithZone:zone];
    copy->_muted = _muted;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeBool:_muted forKey:@"muted"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        _muted = [coder decodeBoolForKey:@"muted"];
    return self;
}

@end

@implementation CXSetGroupCallAction {
    NSUUID *_callUUIDToGroupWith;
}

@dynamic callUUIDToGroupWith;

- (instancetype)initWithCallUUID:(NSUUID *)callUUID callUUIDToGroupWith:(NSUUID *)callUUIDToGroupWith
{
    if ((self = [super initWithCallUUID:callUUID]))
        _callUUIDToGroupWith = [callUUIDToGroupWith copy];
    return self;
}

- (NSUUID *)callUUIDToGroupWith
{
    return _callUUIDToGroupWith;
}

- (void)setCallUUIDToGroupWith:(NSUUID *)callUUIDToGroupWith
{
    _callUUIDToGroupWith = [callUUIDToGroupWith copy];
}

- (SEL)charon_performSelector
{
    return @selector(provider:performSetGroupCallAction:);
}

- (id)copyWithZone:(NSZone *)zone
{
    CXSetGroupCallAction *copy = [super copyWithZone:zone];
    copy->_callUUIDToGroupWith = [_callUUIDToGroupWith copy];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_callUUIDToGroupWith forKey:@"callUUIDToGroupWith"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        _callUUIDToGroupWith = [[coder decodeObjectOfClass:[NSUUID class] forKey:@"callUUIDToGroupWith"] copy];
    return self;
}

@end

@implementation CXPlayDTMFCallAction {
    NSString *_digits;
    CXPlayDTMFCallActionType _type;
}

@dynamic digits, type;

- (instancetype)initWithCallUUID:(NSUUID *)callUUID digits:(NSString *)digits type:(CXPlayDTMFCallActionType)type
{
    if ((self = [super initWithCallUUID:callUUID])) {
        _digits = [digits copy];
        _type = type;
    }
    return self;
}

- (NSString *)digits
{
    return _digits;
}

- (void)setDigits:(NSString *)digits
{
    _digits = [digits copy];
}

- (CXPlayDTMFCallActionType)type
{
    return _type;
}

- (void)setType:(CXPlayDTMFCallActionType)type
{
    _type = type;
}

- (SEL)charon_performSelector
{
    return @selector(provider:performPlayDTMFCallAction:);
}

- (id)copyWithZone:(NSZone *)zone
{
    CXPlayDTMFCallAction *copy = [super copyWithZone:zone];
    copy->_digits = [_digits copy];
    copy->_type = _type;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_digits forKey:@"digits"];
    [coder encodeInteger:_type forKey:@"type"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _digits = [[coder decodeObjectOfClass:[NSString class] forKey:@"digits"] copy];
        _type = (CXPlayDTMFCallActionType)[coder decodeIntegerForKey:@"type"];
    }
    return self;
}

@end
