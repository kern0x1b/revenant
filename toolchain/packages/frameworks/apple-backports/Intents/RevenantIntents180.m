#import <Intents/Intents.h>
#import <objc/runtime.h>
#import "RevenantIntents262.h"
#import "../../../runtimes/revenant-coding/files/RevenantCoding.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

static NSString *const revenant_message_sticker_key = @"INMessage.sticker";
static NSString *const revenant_message_reaction_key = @"INMessage.reaction";
static NSString *const revenant_message_referenced_key = @"INMessage.referencedMessage";

static const void *revenant_message_sticker_tag = &revenant_message_sticker_tag;
static const void *revenant_message_reaction_tag = &revenant_message_reaction_tag;
static const void *revenant_message_referenced_tag = &revenant_message_referenced_tag;

static void revenant_intents_keep_referenced(INMessage *message, INMessage *_Nullable referenced)
{
    objc_setAssociatedObject(message, revenant_message_referenced_tag, referenced,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static INMessage *_Nullable revenant_intents_referenced(INMessage *message)
{
    return objc_getAssociatedObject(message, revenant_message_referenced_tag);
}

static void revenant_intents_carry_referenced(INMessage *copy, INMessage *message)
{
    revenant_intents_keep_referenced(copy, revenant_intents_referenced(message));
}

NS_ASSUME_NONNULL_BEGIN

@interface INMessage (RevenantMessage18)

- (instancetype)initWithIdentifier:(NSString *)identifier
            conversationIdentifier:(nullable NSString *)conversationIdentifier
                           content:(nullable NSString *)content
                          dateSent:(nullable NSDate *)dateSent
                            sender:(nullable INPerson *)sender
                        recipients:(nullable NSArray<INPerson *> *)recipients
                         groupName:(nullable INSpeakableString *)groupName
                       serviceName:(nullable NSString *)serviceName
                       messageType:(INMessageType)messageType
                 referencedMessage:(nullable INMessage *)referencedMessage
                      sticker:(nullable INSticker *)sticker
                     reaction:(nullable INMessageReaction *)reaction;

- (instancetype)initWithIdentifier:(NSString *)identifier
            conversationIdentifier:(nullable NSString *)conversationIdentifier
                           content:(nullable NSString *)content
                          dateSent:(nullable NSDate *)dateSent
                            sender:(nullable INPerson *)sender
                        recipients:(nullable NSArray<INPerson *> *)recipients
                         groupName:(nullable INSpeakableString *)groupName
                       serviceName:(nullable NSString *)serviceName
                       messageType:(INMessageType)messageType
                 referencedMessage:(nullable INMessage *)referencedMessage
                        reaction:(nullable INMessageReaction *)reaction;

@property (readwrite, copy, nullable, NS_NONATOMIC_IOSONLY) INSticker *sticker;
@property (readwrite, copy, nullable, NS_NONATOMIC_IOSONLY) INMessageReaction *reaction;

@end

NS_ASSUME_NONNULL_END

@implementation INMessage (RevenantMessage18)

- (INSticker *)sticker
{
    return objc_getAssociatedObject(self, revenant_message_sticker_tag);
}

- (void)setSticker:(INSticker *)sticker
{
    objc_setAssociatedObject(self, revenant_message_sticker_tag, [sticker copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (INMessageReaction *)reaction
{
    return objc_getAssociatedObject(self, revenant_message_reaction_tag);
}

- (void)setReaction:(INMessageReaction *)reaction
{
    objc_setAssociatedObject(self, revenant_message_reaction_tag, [reaction copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (instancetype)initWithIdentifier:(NSString *)identifier
            conversationIdentifier:(NSString *)conversationIdentifier
                           content:(NSString *)content
                          dateSent:(NSDate *)dateSent
                            sender:(INPerson *)sender
                        recipients:(NSArray<INPerson *> *)recipients
                         groupName:(INSpeakableString *)groupName
                       serviceName:(NSString *)serviceName
                       messageType:(INMessageType)messageType
                 referencedMessage:(INMessage *)referencedMessage
                      sticker:(INSticker *)sticker
                     reaction:(INMessageReaction *)reaction
{
    if ((self = [self initWithIdentifier:identifier
                  conversationIdentifier:conversationIdentifier
                                 content:content
                                dateSent:dateSent
                                  sender:sender
                              recipients:recipients
                               groupName:groupName
                             messageType:messageType
                             serviceName:serviceName])) {
        self.sticker = sticker;
        self.reaction = reaction;
        revenant_intents_keep_referenced(self, referencedMessage);
    }
    return self;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
            conversationIdentifier:(NSString *)conversationIdentifier
                           content:(NSString *)content
                          dateSent:(NSDate *)dateSent
                            sender:(INPerson *)sender
                        recipients:(NSArray<INPerson *> *)recipients
                         groupName:(INSpeakableString *)groupName
                       serviceName:(NSString *)serviceName
                       messageType:(INMessageType)messageType
                 referencedMessage:(INMessage *)referencedMessage
                        reaction:(INMessageReaction *)reaction
{
    if ((self = [self initWithIdentifier:identifier
                  conversationIdentifier:conversationIdentifier
                                 content:content
                                dateSent:dateSent
                                  sender:sender
                              recipients:recipients
                               groupName:groupName
                             messageType:messageType
                             serviceName:serviceName])) {
        self.reaction = reaction;
        revenant_intents_keep_referenced(self, referencedMessage);
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    INMessage *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    copy.sticker = self.sticker;
    copy.reaction = self.reaction;
    revenant_intents_carry_referenced(copy, self);
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
    [coder encodeObject:self.sticker forKey:revenant_message_sticker_key];
    [coder encodeObject:self.reaction forKey:revenant_message_reaction_key];
    [coder encodeObject:revenant_intents_referenced(self) forKey:revenant_message_referenced_key];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = revenant_intents_super_init(self, [NSObject class])))
        revenant_intents_decode(self, coder);
    INSticker *sticker = [coder decodeObjectOfClass:[INSticker class] forKey:revenant_message_sticker_key];
    if (sticker) {
        self.sticker = sticker;
    }
    INMessageReaction *reaction = [coder decodeObjectOfClass:[INMessageReaction class] forKey:revenant_message_reaction_key];
    if (reaction) {
        self.reaction = reaction;
    }
    INMessage *referenced = [coder decodeObjectOfClass:[INMessage class] forKey:revenant_message_referenced_key];
    if (referenced) {
        revenant_intents_keep_referenced(self, referenced);
    }
    return self;
}

@end
