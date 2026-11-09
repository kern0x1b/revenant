#if defined(REVENANT_HOST_BUILD)
#define INSearchForMessagesIntent INSearchForMessagesIntentRevenant
#define INSetMessageAttributeIntent INSetMessageAttributeIntentRevenant
#define REVENANT_INTENT_SUPER_INIT(self) revenant_intents_super_init(self, [NSObject class])
#else
#define REVENANT_INTENT_SUPER_INIT(self) [super init]
#endif

#import <Intents/Intents.h>
#import <Intents/INSearchForMessagesIntent.h>
#import <Intents/INSearchForMessagesIntent_Deprecated.h>
#import <Intents/INSetMessageAttributeIntent.h>
#import <Intents/INMessageAttribute.h>
#import <Intents/INMessageAttributeOptions.h>
#import <Intents/INConditionalOperator.h>

#import "coding/RevenantCoding.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *revenant_operator_name(INConditionalOperator conditionalOperator)
{
    switch (conditionalOperator) {
        case INConditionalOperatorAll:
            return @"all";
        case INConditionalOperatorAny:
            return @"any";
        case INConditionalOperatorNone:
            return @"none";
    }
    return [NSString stringWithFormat:@"%ld", (long)conditionalOperator];
}

static NSString *revenant_attribute_name(INMessageAttribute attribute)
{
    switch (attribute) {
        case INMessageAttributeUnknown:
            return @"unknown";
        case INMessageAttributeRead:
            return @"read";
        case INMessageAttributeUnread:
            return @"unread";
        case INMessageAttributeFlagged:
            return @"flagged";
        case INMessageAttributeUnflagged:
            return @"unflagged";
        case INMessageAttributePlayed:
            return @"played";
    }
    return [NSString stringWithFormat:@"%ld", (long)attribute];
}

#pragma mark - INSearchForMessagesIntent

@implementation INSearchForMessagesIntent {
    NSArray<INPerson *> *_recipients;
    INConditionalOperator _recipientsOperator;
    NSArray<INPerson *> *_senders;
    INConditionalOperator _sendersOperator;
    NSArray<NSString *> *_searchTerms;
    INConditionalOperator _searchTermsOperator;
    INMessageAttributeOptions _attributes;
    INDateComponentsRange *_dateTimeRange;
    NSArray<NSString *> *_identifiers;
    INConditionalOperator _identifiersOperator;
    NSArray<NSString *> *_notificationIdentifiers;
    INConditionalOperator _notificationIdentifiersOperator;
    NSArray<INSpeakableString *> *_speakableGroupNames;
    INConditionalOperator _speakableGroupNamesOperator;
    NSArray<NSString *> *_conversationIdentifiers;
    INConditionalOperator _conversationIdentifiersOperator;
}

@synthesize recipients = _recipients;
@synthesize recipientsOperator = _recipientsOperator;
@synthesize senders = _senders;
@synthesize sendersOperator = _sendersOperator;
@synthesize searchTerms = _searchTerms;
@synthesize searchTermsOperator = _searchTermsOperator;
@synthesize attributes = _attributes;
@synthesize dateTimeRange = _dateTimeRange;
@synthesize identifiers = _identifiers;
@synthesize identifiersOperator = _identifiersOperator;
@synthesize notificationIdentifiers = _notificationIdentifiers;
@synthesize notificationIdentifiersOperator = _notificationIdentifiersOperator;
@synthesize speakableGroupNames = _speakableGroupNames;
@synthesize speakableGroupNamesOperator = _speakableGroupNamesOperator;
@synthesize conversationIdentifiers = _conversationIdentifiers;
@synthesize conversationIdentifiersOperator = _conversationIdentifiersOperator;

- (instancetype)initWithRecipients:(NSArray<INPerson *> *)recipients
                           senders:(NSArray<INPerson *> *)senders
                       searchTerms:(NSArray<NSString *> *)searchTerms
                        attributes:(INMessageAttributeOptions)attributes
                     dateTimeRange:(INDateComponentsRange *)dateTimeRange
                       identifiers:(NSArray<NSString *> *)identifiers
           notificationIdentifiers:(NSArray<NSString *> *)notificationIdentifiers
               speakableGroupNames:(NSArray<INSpeakableString *> *)speakableGroupNames
           conversationIdentifiers:(NSArray<NSString *> *)conversationIdentifiers
{
    if ((self = REVENANT_INTENT_SUPER_INIT(self))) {
        _recipients = [recipients copy];
        _senders = [senders copy];
        _searchTerms = [searchTerms copy];
        _attributes = attributes;
        _dateTimeRange = [dateTimeRange copy];
        _identifiers = [identifiers copy];
        _notificationIdentifiers = [notificationIdentifiers copy];
        _speakableGroupNames = [speakableGroupNames copy];
        _conversationIdentifiers = [conversationIdentifiers copy];
    }
    return self;
}

- (instancetype)initWithRecipients:(NSArray<INPerson *> *)recipients
                           senders:(NSArray<INPerson *> *)senders
                       searchTerms:(NSArray<NSString *> *)searchTerms
                        attributes:(INMessageAttributeOptions)attributes
                     dateTimeRange:(INDateComponentsRange *)dateTimeRange
                       identifiers:(NSArray<NSString *> *)identifiers
           notificationIdentifiers:(NSArray<NSString *> *)notificationIdentifiers
               speakableGroupNames:(NSArray<INSpeakableString *> *)speakableGroupNames
{
    return [self initWithRecipients:recipients senders:senders searchTerms:searchTerms attributes:attributes
                      dateTimeRange:dateTimeRange identifiers:identifiers notificationIdentifiers:notificationIdentifiers
                speakableGroupNames:speakableGroupNames conversationIdentifiers:nil];
}

- (instancetype)initWithRecipients:(NSArray<INPerson *> *)recipients
                           senders:(NSArray<INPerson *> *)senders
                       searchTerms:(NSArray<NSString *> *)searchTerms
                        attributes:(INMessageAttributeOptions)attributes
                     dateTimeRange:(INDateComponentsRange *)dateTimeRange
                       identifiers:(NSArray<NSString *> *)identifiers
           notificationIdentifiers:(NSArray<NSString *> *)notificationIdentifiers
                        groupNames:(NSArray<NSString *> *)groupNames
{
    NSMutableArray<INSpeakableString *> *speakableGroupNames = groupNames ? [NSMutableArray arrayWithCapacity:groupNames.count] : nil;
    for (NSString *groupName in groupNames) {
        [speakableGroupNames addObject:[[INSpeakableString alloc] initWithSpokenPhrase:groupName]];
    }
    return [self initWithRecipients:recipients senders:senders searchTerms:searchTerms attributes:attributes
                      dateTimeRange:dateTimeRange identifiers:identifiers notificationIdentifiers:notificationIdentifiers
                speakableGroupNames:speakableGroupNames conversationIdentifiers:nil];
}

- (instancetype)init
{
    return [self initWithRecipients:nil senders:nil searchTerms:nil attributes:0 dateTimeRange:nil identifiers:nil
            notificationIdentifiers:nil speakableGroupNames:nil conversationIdentifiers:nil];
}

- (NSArray<NSString *> *)groupNames
{
    NSMutableArray<NSString *> *names = _speakableGroupNames ? [NSMutableArray arrayWithCapacity:_speakableGroupNames.count] : nil;
    for (INSpeakableString *name in _speakableGroupNames) {
        [names addObject:name.spokenPhrase];
    }
    return names;
}

- (INConditionalOperator)groupNamesOperator
{
    return _speakableGroupNamesOperator;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p identifiers=%@ (%@) notificationIdentifiers=%@ (%@) attributes=%lu>",
            NSStringFromClass([self class]), self, _identifiers, revenant_operator_name(_identifiersOperator),
            _notificationIdentifiers, revenant_operator_name(_notificationIdentifiersOperator), (unsigned long)_attributes];
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
    INSearchForMessagesIntent *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    return revenant_intents_equal(self, object, [INSearchForMessagesIntent class]);
}

- (NSUInteger)hash
{
    return revenant_intents_hash(self, [INSearchForMessagesIntent class]);
}

@end

#pragma mark - INSetMessageAttributeIntent

@implementation INSetMessageAttributeIntent {
    NSArray<NSString *> *_identifiers;
    INMessageAttribute _attribute;
}

@synthesize identifiers = _identifiers;
@synthesize attribute = _attribute;

- (instancetype)initWithIdentifiers:(NSArray<NSString *> *)identifiers attribute:(INMessageAttribute)attribute
{
    if ((self = REVENANT_INTENT_SUPER_INIT(self))) {
        _identifiers = [identifiers copy];
        _attribute = attribute;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithIdentifiers:nil attribute:INMessageAttributeUnknown];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p identifiers=%@ attribute=%@>", NSStringFromClass([self class]), self, _identifiers,
            revenant_attribute_name(_attribute)];
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
    INSetMessageAttributeIntent *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    return revenant_intents_equal(self, object, [INSetMessageAttributeIntent class]);
}

- (NSUInteger)hash
{
    return revenant_intents_hash(self, [INSetMessageAttributeIntent class]);
}

@end
