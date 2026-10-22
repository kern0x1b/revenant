#if defined(REVENANT_HOST_BUILD)
#define INPersonHandle INPersonHandleRevenant
#define INPerson INPersonRevenant
#define INSendMessageIntent INSendMessageIntentRevenant
#define REVENANT_MESSAGE_SUPER_INIT(self) revenant_intents_super_init(self, [NSObject class])
#else
#define REVENANT_MESSAGE_SUPER_INIT(self) [super init]
#endif

#import <Intents/Intents.h>
#import <Intents/INPerson.h>
#import <Intents/INPersonHandle.h>
#import <Intents/INSendMessageIntent_Deprecated.h>
#import <objc/runtime.h>

#import "coding/RevenantCoding.h"

@implementation INPersonHandle {
    NSString *_value;
    INPersonHandleType _type;
    INPersonHandleLabel _label;
}

@synthesize value = _value;
@synthesize type = _type;
@synthesize label = _label;

- (instancetype)initWithValue:(NSString *)value type:(INPersonHandleType)type
{
    return [self initWithValue:value type:type label:nil];
}

- (instancetype)initWithValue:(NSString *)value type:(INPersonHandleType)type label:(INPersonHandleLabel)label
{
    if ((self = [super init])) {
        _value = [value copy];
        _type = type;
        _label = [label copy];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *value = [coder decodeObjectOfClass:[NSString class] forKey:@"value"];
    INPersonHandleType type = [coder decodeIntegerForKey:@"type"];
    NSString *label = [coder decodeObjectOfClass:[NSString class] forKey:@"label"];
    return [self initWithValue:value type:type label:label];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_value forKey:@"value"];
    [coder encodeInteger:_type forKey:@"type"];
    [coder encodeObject:_label forKey:@"label"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithValue:_value type:_type label:_label];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    INPersonHandle *other = object;
    return _type == other.type &&
        ((_value == other.value) || [_value isEqualToString:other.value]) &&
        ((_label == other.label) || [_label isEqualToString:other.label]);
}

- (NSUInteger)hash
{
    return _value.hash ^ (_label.hash << 1) ^ (NSUInteger)_type;
}

@end

@implementation INPerson {
    INPersonHandle *_personHandle;
    NSPersonNameComponents *_nameComponents;
    NSString *_explicitDisplayName;
    INImage *_image;
    NSString *_contactIdentifier;
    NSString *_customIdentifier;
    INPersonRelationship _relationship;
    NSArray<INPersonHandle *> *_aliases;
    INPersonSuggestionType _suggestionType;
    BOOL _isMe;
    BOOL _contactSuggestion;
}

@synthesize personHandle = _personHandle;
@synthesize nameComponents = _nameComponents;
@synthesize image = _image;
@synthesize contactIdentifier = _contactIdentifier;
@synthesize customIdentifier = _customIdentifier;
@synthesize relationship = _relationship;
@synthesize contactSuggestion = _contactSuggestion;

- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle
                       nameComponents:(NSPersonNameComponents *)nameComponents
                          displayName:(NSString *)displayName
                                image:(INImage *)image
                    contactIdentifier:(NSString *)contactIdentifier
                     customIdentifier:(NSString *)customIdentifier
{
    return [self initWithPersonHandle:personHandle nameComponents:nameComponents displayName:displayName image:image contactIdentifier:contactIdentifier customIdentifier:customIdentifier isMe:NO];
}

- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle
                       nameComponents:(NSPersonNameComponents *)nameComponents
                          displayName:(NSString *)displayName
                                image:(INImage *)image
                    contactIdentifier:(NSString *)contactIdentifier
                     customIdentifier:(NSString *)customIdentifier
                         relationship:(INPersonRelationship)relationship
{
    self = [self initWithPersonHandle:personHandle nameComponents:nameComponents displayName:displayName image:image contactIdentifier:contactIdentifier customIdentifier:customIdentifier isMe:NO];
    if (self)
        _relationship = [relationship copy];
    return self;
}

- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle
                       nameComponents:(NSPersonNameComponents *)nameComponents
                          displayName:(NSString *)displayName
                                image:(INImage *)image
                    contactIdentifier:(NSString *)contactIdentifier
                     customIdentifier:(NSString *)customIdentifier
                                isMe:(BOOL)isMe
{
    if ((self = [super init])) {
        _personHandle = [personHandle copy];
        _nameComponents = [nameComponents copy];
        _explicitDisplayName = [displayName copy];
        _image = [image copy];
        _contactIdentifier = [contactIdentifier copy];
        _customIdentifier = [customIdentifier copy];
        _isMe = isMe;
    }
    return self;
}

- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle
                       nameComponents:(NSPersonNameComponents *)nameComponents
                          displayName:(NSString *)displayName
                                image:(INImage *)image
                    contactIdentifier:(NSString *)contactIdentifier
                     customIdentifier:(NSString *)customIdentifier
                                isMe:(BOOL)isMe
                     suggestionType:(INPersonSuggestionType)suggestionType
{
    self = [self initWithPersonHandle:personHandle nameComponents:nameComponents displayName:displayName image:image contactIdentifier:contactIdentifier customIdentifier:customIdentifier isMe:isMe];
    if (self)
        _suggestionType = suggestionType;
    return self;
}

- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle
                       nameComponents:(NSPersonNameComponents *)nameComponents
                          displayName:(NSString *)displayName
                                image:(INImage *)image
                    contactIdentifier:(NSString *)contactIdentifier
                     customIdentifier:(NSString *)customIdentifier
                 isContactSuggestion:(BOOL)isContactSuggestion
                      suggestionType:(INPersonSuggestionType)suggestionType
{
    self = [self initWithPersonHandle:personHandle nameComponents:nameComponents displayName:displayName image:image contactIdentifier:contactIdentifier customIdentifier:customIdentifier isMe:NO];
    if (self) {
        _contactSuggestion = isContactSuggestion;
        _suggestionType = suggestionType;
    }
    return self;
}

- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle
                       nameComponents:(NSPersonNameComponents *)nameComponents
                          displayName:(NSString *)displayName
                                image:(INImage *)image
                    contactIdentifier:(NSString *)contactIdentifier
                     customIdentifier:(NSString *)customIdentifier
                              aliases:(NSArray<INPersonHandle *> *)aliases
                       suggestionType:(INPersonSuggestionType)suggestionType
{
    self = [self initWithPersonHandle:personHandle nameComponents:nameComponents displayName:displayName image:image contactIdentifier:contactIdentifier customIdentifier:customIdentifier isMe:NO];
    if (self) {
        _aliases = [aliases copy];
        _suggestionType = suggestionType;
    }
    return self;
}

- (NSArray<INPersonHandle *> *)aliases
{
    return _aliases;
}

- (INPersonSuggestionType)suggestionType
{
    return _suggestionType;
}

- (NSString *)displayName
{
    if (_explicitDisplayName)
        return _explicitDisplayName;
    if (_nameComponents) {
        NSString *formatted = [NSPersonNameComponentsFormatter localizedStringFromPersonNameComponents:_nameComponents style:NSPersonNameComponentsFormatterStyleDefault options:0];
        if (formatted.length)
            return formatted;
    }
    return _personHandle.value ?: @"";
}

- (BOOL)isContactSuggestion
{
    return _contactSuggestion;
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
    INPerson *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    INPerson *other = object;
    return ((_personHandle == other.personHandle) || [_personHandle isEqual:other.personHandle]) &&
        ((_nameComponents == other.nameComponents) || [_nameComponents isEqual:other.nameComponents]) &&
        ((_explicitDisplayName == other->_explicitDisplayName) || [_explicitDisplayName isEqualToString:other->_explicitDisplayName]) &&
        ((_image == other.image) || [_image isEqual:other.image]) &&
        ((_contactIdentifier == other.contactIdentifier) || [_contactIdentifier isEqualToString:other.contactIdentifier]) &&
        ((_customIdentifier == other.customIdentifier) || [_customIdentifier isEqualToString:other.customIdentifier]) &&
        ((_relationship == other.relationship) || [_relationship isEqualToString:other.relationship]) &&
        ((_aliases == other.aliases) || [_aliases isEqualToArray:other.aliases]) &&
        _suggestionType == other.suggestionType && _contactSuggestion == other.isContactSuggestion;
}

- (NSUInteger)hash
{
    return _personHandle.hash ^ (_nameComponents.hash << 1) ^ (_explicitDisplayName.hash << 2) ^ (_contactIdentifier.hash << 3) ^ (_customIdentifier.hash << 4);
}

@end

@implementation INSendMessageIntent {
    NSArray<INPerson *> *_recipients;
    INOutgoingMessageType _outgoingMessageType;
    NSString *_content;
    INSpeakableString *_speakableGroupName;
    NSString *_conversationIdentifier;
    NSString *_serviceName;
    INPerson *_sender;
    NSArray<INSendMessageAttachment *> *_attachments;
}

@synthesize recipients = _recipients;
@synthesize outgoingMessageType = _outgoingMessageType;
@synthesize content = _content;
@synthesize speakableGroupName = _speakableGroupName;
@synthesize conversationIdentifier = _conversationIdentifier;
@synthesize serviceName = _serviceName;
@synthesize sender = _sender;
@synthesize attachments = _attachments;

- (instancetype)initWithRecipients:(NSArray<INPerson *> *)recipients
               outgoingMessageType:(INOutgoingMessageType)outgoingMessageType
                           content:(NSString *)content
                speakableGroupName:(INSpeakableString *)speakableGroupName
            conversationIdentifier:(NSString *)conversationIdentifier
                       serviceName:(NSString *)serviceName
                            sender:(INPerson *)sender
                       attachments:(NSArray<INSendMessageAttachment *> *)attachments
{
    if ((self = REVENANT_MESSAGE_SUPER_INIT(self))) {
        _recipients = [recipients copy];
        _outgoingMessageType = outgoingMessageType;
        _content = [content copy];
        _speakableGroupName = [speakableGroupName copy];
        _conversationIdentifier = [conversationIdentifier copy];
        _serviceName = [serviceName copy];
        _sender = [sender copy];
        _attachments = [attachments copy];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithRecipients:nil outgoingMessageType:INOutgoingMessageTypeUnknown content:nil speakableGroupName:nil conversationIdentifier:nil serviceName:nil sender:nil attachments:nil];
}

- (instancetype)initWithRecipients:(NSArray<INPerson *> *)recipients
                           content:(NSString *)content
                         groupName:(NSString *)groupName
                       serviceName:(NSString *)serviceName
                            sender:(INPerson *)sender
{
    INSpeakableString *speakableGroupName = groupName ? [[INSpeakableString alloc] initWithSpokenPhrase:groupName] : nil;
    return [self initWithRecipients:recipients outgoingMessageType:INOutgoingMessageTypeUnknown content:content speakableGroupName:speakableGroupName conversationIdentifier:nil serviceName:serviceName sender:sender attachments:nil];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self initWithRecipients:nil outgoingMessageType:INOutgoingMessageTypeUnknown content:nil speakableGroupName:nil conversationIdentifier:nil serviceName:nil sender:nil attachments:nil]))
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INSendMessageIntent *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    INSendMessageIntent *other = object;
    return ((_recipients == other.recipients) || [_recipients isEqualToArray:other.recipients]) &&
        _outgoingMessageType == other.outgoingMessageType &&
        ((_content == other.content) || [_content isEqualToString:other.content]) &&
        ((_speakableGroupName == other.speakableGroupName) || [_speakableGroupName isEqual:other.speakableGroupName]) &&
        ((_conversationIdentifier == other.conversationIdentifier) || [_conversationIdentifier isEqualToString:other.conversationIdentifier]) &&
        ((_serviceName == other.serviceName) || [_serviceName isEqualToString:other.serviceName]) &&
        ((_sender == other.sender) || [_sender isEqual:other.sender]) &&
        ((_attachments == other.attachments) || [_attachments isEqualToArray:other.attachments]);
}

- (NSUInteger)hash
{
    return _recipients.hash ^ (_content.hash << 1) ^ (_conversationIdentifier.hash << 2) ^ (_serviceName.hash << 3);
}

@end
