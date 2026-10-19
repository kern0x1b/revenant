//
//  IN17_0.m
//  Intents
//
//  The three members iOS 17.0 added to INMessage, and nothing else this file's release carries:
//
//      -[INMessage initWithIdentifier:...:serviceName:attachmentFiles:]
//      -[INMessage initWithIdentifier:...:serviceName:linkMetadata:]
//      -[INMessage initWithIdentifier:...:serviceName:messageType:numberOfAttachments:]
//      INMessage.attachmentFiles      NSArray<INFile *> *
//      INMessage.numberOfAttachments  NSNumber *
//      INMessage.linkMetadata         INMessageLinkMetadata *
//
//  Why this is a category and not a class of its own, and why it is a file and not a group of
//  the generator's: INMessage is a class of the 10.0.1 group, so IN10_0_1.m defines it and no
//  second file may define it again. Its 17.0 members are invisible to that file's generator for
//  one measured reason - the group is generated from the port's own SDK, iPhoneOS 16.4, whose
//  INMessage.h declares none of these six (all six are marked API_AVAILABLE(ios(17.0),
//  watchos(10.0)) in the header of iPhoneOS 26.2, which is where their contract is read from).
//  So the members are written here, as a category on the class its own object owns, and
//  facts/Intents/Intents.md carries the measurement and what a caller gets.
//
//  Where the three values are kept: an associated object per instance. A class extension may
//  declare ivars in a translation unit that is not the one with the @implementation - clang
//  accepts it and the file compiles - but it does not link, because the ivar symbol is defined by
//  the implementation's own unit and nothing else defines it:
//
//      $ xcrun clang -fobjc-arc -framework Foundation -o t a.m b.m main.m
//      Undefined symbols for architecture arm64:
//        "_OBJC_IVAR_$_Foo._lateIvar", referenced from:
//            -[Foo(Late) lateIvar] in b.o
//            -[Foo(Late) setLateIvar:] in b.o
//
//  So the three cannot be ivars of the class from here, and -copyWithZone:, -encodeWithCoder: and
//  -initWithCoder: - the class's own three, which walk its ivar list through the one helper in
//  packages/c/charon-coding - would leave them behind. They are answered below beside the six,
//  which is what makes a copy and an archive carry all thirteen values of an INMessage instead of
//  ten. Those three are not new API: the SDK's header declares none of them (INMessage takes them
//  from NSObject's protocols), no registry row names any of them, and nothing this file declares
//  is placed by them.
//

#import <Intents/Intents.h>
#import <objc/runtime.h>
#import "CharonIntents262.h"
#import "../../../c/charon-coding/files/CharonCoding.h"

// The header marks this class's -init unavailable, in a header this package does not own and
// cannot add a marking to, so clang reads every initialiser below as a convenience initialiser of
// a class whose designated one is in another file. The warning is about a convention and not about
// behaviour: each of the three delegates to that designated initialiser by name.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static const void *charon_inmessage_attachment_files = &charon_inmessage_attachment_files;
static const void *charon_inmessage_link_metadata = &charon_inmessage_link_metadata;
static const void *charon_inmessage_number_of_attachments = &charon_inmessage_number_of_attachments;

// The keys charon_intents_encode writes one ivar under, which names the class that owns the ivar
// and the ivar's own name. The three here are the keys an INMessage's own attachmentFiles,
// numberOfAttachments and linkMetadata occupy, so an archive written by this class and an archive
// written by the class of iOS 17.0 name the same three keys for the same three values.
static NSString *const charon_inmessage_attachment_files_key = @"INMessage.attachmentFiles";
static NSString *const charon_inmessage_number_of_attachments_key = @"INMessage.numberOfAttachments";
static NSString *const charon_inmessage_link_metadata_key = @"INMessage.linkMetadata";


@implementation INMessage (CharonIntents17)

- (instancetype)initWithIdentifier:(NSString *)identifier
            conversationIdentifier:(NSString *)conversationIdentifier
                           content:(NSString *)content
                          dateSent:(NSDate *)dateSent
                            sender:(INPerson *)sender
                        recipients:(NSArray<INPerson *> *)recipients
                         groupName:(INSpeakableString *)groupName
                       messageType:(INMessageType)messageType
                       serviceName:(NSString *)serviceName
                   attachmentFiles:(NSArray<INFile *> *)attachmentFiles
{
    // Everything of this release's INMessage that the 13.2 initialiser answers, and then the one
    // value of 17.0 that is new here.
    if ((self = [self initWithIdentifier:identifier
                   conversationIdentifier:conversationIdentifier
                                  content:content
                                 dateSent:dateSent
                                   sender:sender
                               recipients:recipients
                                groupName:groupName
                              messageType:messageType
                              serviceName:serviceName])) {
        objc_setAssociatedObject(self, charon_inmessage_attachment_files,
                                 [attachmentFiles copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
                      linkMetadata:(INMessageLinkMetadata *)linkMetadata
{
    // This initialiser is the one of the three that names no messageType, and the header's own
    // enumeration answers for the value it leaves out: INMessageTypeUnspecified is the case the
    // enumeration numbers 0, which is what a parameter of an INMessageType that is not given
    // holds. The property is NS_NONATOMIC_IOSONLY and readonly, so the value is the one an
    // application reads back, and nothing else is free to change it.
    if ((self = [self initWithIdentifier:identifier
                   conversationIdentifier:conversationIdentifier
                                  content:content
                                 dateSent:dateSent
                                   sender:sender
                               recipients:recipients
                                groupName:groupName
                              messageType:INMessageTypeUnspecified
                              serviceName:serviceName])) {
        objc_setAssociatedObject(self, charon_inmessage_link_metadata,
                                 [linkMetadata copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
               numberOfAttachments:(NSNumber *)numberOfAttachments
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
        objc_setAssociatedObject(self, charon_inmessage_number_of_attachments,
                                 [numberOfAttachments copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
}

- (NSArray<INFile *> *)attachmentFiles
{
    return objc_getAssociatedObject(self, charon_inmessage_attachment_files);
}

- (NSNumber *)numberOfAttachments
{
    return objc_getAssociatedObject(self, charon_inmessage_number_of_attachments);
}

- (INMessageLinkMetadata *)linkMetadata
{
    return objc_getAssociatedObject(self, charon_inmessage_link_metadata);
}

#pragma mark - The three of the class's own, so a copy and an archive carry these three too

// The diagnostic: THREE -Wobjc-protocol-method-implementation, one per method below, because
// NSObject's own protocols declare all three and the class implements them too. Inherent to
// answering them here at all, and the one that runs is this category's. Nothing else is silenced
// in this file: measured with -Wall -Wextra, the whole of it is those three and, under the build's
// own -Wno-unguarded-availability flags, nothing.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // The header marks this class's -init unavailable, so the superclass's own -init is called
    // through CharonCoding.h's one definition of it, exactly as the class's own initialiser does.
    if ((self = charon_intents_super_init(self, [NSObject class])))
        charon_intents_decode(self, coder);
    NSArray<INFile *> *attachmentFiles =
        [coder decodeObjectOfClasses:charon_intents_allowed_classes() forKey:charon_inmessage_attachment_files_key];
    if (attachmentFiles)
        objc_setAssociatedObject(self, charon_inmessage_attachment_files,
                                 attachmentFiles, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSNumber *numberOfAttachments =
        [coder decodeObjectOfClasses:charon_intents_allowed_classes() forKey:charon_inmessage_number_of_attachments_key];
    if (numberOfAttachments)
        objc_setAssociatedObject(self, charon_inmessage_number_of_attachments,
                                 numberOfAttachments, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    INMessageLinkMetadata *linkMetadata =
        [coder decodeObjectOfClasses:charon_intents_allowed_classes() forKey:charon_inmessage_link_metadata_key];
    if (linkMetadata)
        objc_setAssociatedObject(self, charon_inmessage_link_metadata,
                                 linkMetadata, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
    NSArray<INFile *> *attachmentFiles = objc_getAssociatedObject(self, charon_inmessage_attachment_files);
    if (attachmentFiles)
        [coder encodeObject:attachmentFiles forKey:charon_inmessage_attachment_files_key];
    NSNumber *numberOfAttachments = objc_getAssociatedObject(self, charon_inmessage_number_of_attachments);
    if (numberOfAttachments)
        [coder encodeObject:numberOfAttachments forKey:charon_inmessage_number_of_attachments_key];
    INMessageLinkMetadata *linkMetadata = objc_getAssociatedObject(self, charon_inmessage_link_metadata);
    if (linkMetadata)
        [coder encodeObject:linkMetadata forKey:charon_inmessage_link_metadata_key];
}

- (id)copyWithZone:(NSZone *)zone
{
    INMessage *copy = [[[self class] allocWithZone:zone] init];
    charon_intents_copy(copy, self);
    objc_setAssociatedObject(copy, charon_inmessage_attachment_files,
                             objc_getAssociatedObject(self, charon_inmessage_attachment_files),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(copy, charon_inmessage_number_of_attachments,
                             objc_getAssociatedObject(self, charon_inmessage_number_of_attachments),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(copy, charon_inmessage_link_metadata,
                             objc_getAssociatedObject(self, charon_inmessage_link_metadata),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return copy;
}

#pragma clang diagnostic pop

@end
