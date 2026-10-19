//
//  CharonIntents180.m
//  Intents
//
//  INMessage's own members of iOS 18: the two initialisers that take a referenced message, a
//  sticker and a reaction, and the sticker and the reaction they keep. Four rows of
//  registry/Intents/ios10.json, and this file is the object that answers them.
//
//  Why a category, and why not in IN10_0_1.m
//  ---------------------------------------------------------------------------
//  INMessage is carried from iOS 10.0 and its @implementation is IN10_0_1.m, which
//  tools/intents/gen-intents.lua writes from the port's own SDK. That SDK is iPhoneOS 16.4
//  (generate.sh's PORT_SDK), and 16.4's INMessage.h declares none of these four: measured,
//  `grep -n 'sticker\|reaction\|referencedMessage\|DESIGNATED' INMessage.h` over each of the three
//  16.4 SDKs on this machine answers only three lines - the NS_DESIGNATED_INITIALIZER of 11.0, of
//  13.2 and of 16.0 - and no property at all. So the generator has nothing in its AST to emit,
//  which is why these four rows came out of it as "the SDK's own headers do not declare this
//  member".
//
//  The contract is therefore read where it is written - iPhoneOS 26.2's INMessage.h, lines 139
//  to 178 for the two initialisers and 206 to 210 for the two properties, word for word - and the
//  port writes it for itself, which is what CharonIntents262.h is for: the declarations this
//  package's SDK does not have. The two types are not new to the port either: INSticker and
//  INMessageReaction are two of the four classes of the 18.0 group and IN18_0.m defines both.
//
//  Why this file and not IN10_0_1.m, and this is a coordination answer and not an architectural one.
//  A member does not have to arrive in its own object's release: IN10_0_1.m already carries
//  INMessage.serviceName (13.2), INMessage.groupName (11.0) and INMessage.audioMessageFile (16.0),
//  and INIntent.donationMetadata (15.0) was put beside its class in CharonIntents100.m. So the
//  tree's own shape would put these four there too. This slice holds ONE object, the one for
//  18.0; IN10_0_1.m is the 10.0 group's generated object and rewriting it is another slice's file,
//  and the generator would have to be changed to emit them. So they are here instead, and the
//  difference that choice costs is named at the bottom of this comment.
//
//  The two values are held beside the object rather than in it, because a **category cannot add an
//  ivar to a class another object implements**, and the file says so. That is the whole cost of
//  putting a member of someone else's class in an object of its own release, and it is the cost
//  Photos/PHPickerConfiguration15.m pays for the same thing.
//
//  What a caller gets
//  ---------------------------------------------------------------------------
//  Both initialisers chain to -initWithIdentifier:...groupName:messageType:serviceName:, which
//  IN10_0_1.m implements and which keeps every value these two parameters name. It is the 13.2
//  initialiser rather than the 16.4 designated one, because the 18.0 pair has no audioMessageFile
//  parameter to hand it - the 26.2 header marks that property deprecated and unavailable on ios -
//  so there is nothing to pass and nothing of the class's own state is left unset.
//
//  INMessage declares NSCopying and NSSecureCoding. Without the three methods at the bottom of
//  this file a copy and an archive would carry the whole object except these values, which is a
//  silent wrong answer rather than a crash, so the three are here. Each calls the package's own
//  helper from CharonCoding.h and adds this file's values, so none of them repeats the ivar walk
//  the class already does - a copy made here still carries everything the class gains later.
//  Were these four in IN10_0_1.m instead, charon_intents_copy's own ivar walk would carry them
//  and none of the three would be needed.
//
//  referencedMessage: is a parameter and not a property: the 26.2 header declares no accessor for
//  it, and this port adds none, because an accessor the SDK does not declare is not a backport.
//  The value the caller handed is kept rather than dropped, so the object is whole, and nothing
//  reads it back because nothing can.
//

#import <Intents/Intents.h>
#import <objc/runtime.h>
#import "CharonIntents262.h"
#import "../../../c/charon-coding/files/CharonCoding.h"

// This file implements three selectors IN10_0_1.m implements on the same class, on purpose: the
// class's copy and its two coding methods walk the ivar list, which cannot see what a category
// holds beside the object, and a copy that dropped these two values would answer wrongly. Clang's
// note that a category is implementing a method its primary class also implements is that
// arrangement, and Photos/PHPickerConfiguration15.m silences it the same way.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

// The keys the three values are carried under. charon_intents_key() in CharonCoding.m spells an
// ivar's key as the class that owns the ivar and the ivar's own name, so that two classes of one
// hierarchy that both have a "date" never read each other's; these three follow that spelling for
// the three values an ivar list cannot see. None of the three collides with an ivar key of this
// class: INMessage's ivars are audioMessageFile, content, conversationIdentifier, dateSent,
// groupName, identifier, messageType, recipients, sender and serviceName (IN10_0_1.m), so no
// "INMessage.<name>" an ivar key builds is one of these three.
static NSString *const charon_message_sticker_key = @"INMessage.sticker";
static NSString *const charon_message_reaction_key = @"INMessage.reaction";
static NSString *const charon_message_referenced_key = @"INMessage.referencedMessage";

static const void *charon_message_sticker_tag = &charon_message_sticker_tag;
static const void *charon_message_reaction_tag = &charon_message_reaction_tag;
static const void *charon_message_referenced_tag = &charon_message_referenced_tag;

// The three below hold and carry the referenced message, the one value of the two initialisers that
// the 26.2 header declares no accessor for. They are static and defined here because this file
// exports no API symbol of its own - a category's method implementations are not nm-visible
// exports, tools/release-split.lua's blind-spot note says so - and a C function in a file that
// exports a band's API is undefined in every later band.
static void charon_intents_keep_referenced(INMessage *message, INMessage *_Nullable referenced)
{
    objc_setAssociatedObject(message, charon_message_referenced_tag, referenced,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static INMessage *_Nullable charon_intents_referenced(INMessage *message)
{
    return objc_getAssociatedObject(message, charon_message_referenced_tag);
}

static void charon_intents_carry_referenced(INMessage *copy, INMessage *message)
{
    charon_intents_keep_referenced(copy, charon_intents_referenced(message));
}

NS_ASSUME_NONNULL_BEGIN

// INMessage of iOS 18, over the class IN10_0_1.m implements. The header marks the sticker variant
// NS_DESIGNATED_INITIALIZER, and that marking is not repeated here: this port's INMessage has the
// designated initialiser the 16.4 header names (IN10_0_1.m's
// -initWithIdentifier:...groupName:messageType:serviceName:audioMessageFile:), the marking is a
// compile-time convention and has no runtime effect, and a category cannot change which
// initialiser of a class is designated.
@interface INMessage (CharonMessage18)

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

@implementation INMessage (CharonMessage18)

- (INSticker *)sticker
{
    return objc_getAssociatedObject(self, charon_message_sticker_tag);
}

- (void)setSticker:(INSticker *)sticker
{
    // The header's own ownership: a sticker gets a copy of the one it is handed, so two messages
    // given the same sticker do not share it.
    objc_setAssociatedObject(self, charon_message_sticker_tag, [sticker copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (INMessageReaction *)reaction
{
    return objc_getAssociatedObject(self, charon_message_reaction_tag);
}

- (void)setReaction:(INMessageReaction *)reaction
{
    objc_setAssociatedObject(self, charon_message_reaction_tag, [reaction copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    // IN10_0_1.m's own 13.2 initialiser keeps every value these parameters name, and the two of
    // 18.0 are stored through their own setters, which copy as the header says. The 16.4
    // designated initialiser is not the one chained to: the 18.0 pair has no audioMessageFile
    // parameter, so there is nothing to hand it.
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
        charon_intents_keep_referenced(self, referencedMessage);
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
        charon_intents_keep_referenced(self, referencedMessage);
    }
    return self;
}

// The copy. The class's own -copyWithZone: is IN10_0_1.m's, and it is the one being replaced: it
// makes a new message and hands it to charon_intents_copy, which walks the ivar list of the class
// and of every class above it. That walk cannot see the three values this file holds beside the
// object, so they are carried here through their own accessors - and through the class's own walk
// for everything else, so the copy stays true as the class grows.
- (id)copyWithZone:(NSZone *)zone
{
    // [self class] and not INMessage, so a subclass's copy is a subclass, which is what the
    // class's own -copyWithZone: in IN10_0_1.m does.
    INMessage *copy = [[[self class] allocWithZone:zone] init];
    charon_intents_copy(copy, self);
    copy.sticker = self.sticker;
    copy.reaction = self.reaction;
    charon_intents_carry_referenced(copy, self);
    return copy;
}

// The archive. The class declares NSSecureCoding and both of these replace IN10_0_1.m's, for the
// same reason as the copy. The keys are CharonCoding.h's own spelling (the class that owns the
// value, then the value's own name), and each value is a single object of a class this port
// carries and whose own +supportsSecureCoding is YES, which is what NSSecureCoding asks a keyed
// archive to be told.
- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
    [coder encodeObject:self.sticker forKey:charon_message_sticker_key];
    [coder encodeObject:self.reaction forKey:charon_message_reaction_key];
    [coder encodeObject:charon_intents_referenced(self) forKey:charon_message_referenced_key];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = charon_intents_super_init(self, [NSObject class])))
        charon_intents_decode(self, coder);
    INSticker *sticker = [coder decodeObjectOfClass:[INSticker class] forKey:charon_message_sticker_key];
    if (sticker) {
        self.sticker = sticker;
    }
    INMessageReaction *reaction = [coder decodeObjectOfClass:[INMessageReaction class] forKey:charon_message_reaction_key];
    if (reaction) {
        self.reaction = reaction;
    }
    INMessage *referenced = [coder decodeObjectOfClass:[INMessage class] forKey:charon_message_referenced_key];
    if (referenced) {
        charon_intents_keep_referenced(self, referenced);
    }
    return self;
}

@end