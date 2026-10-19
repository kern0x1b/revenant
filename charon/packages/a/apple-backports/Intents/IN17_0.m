#import <Intents/Intents.h>
#import <objc/runtime.h>
#import "CharonIntents262.h"
#import "../../../c/charon-coding/files/CharonCoding.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static const void *charon_inmessage_attachment_files = &charon_inmessage_attachment_files;
static const void *charon_inmessage_link_metadata = &charon_inmessage_link_metadata;
static const void *charon_inmessage_number_of_attachments = &charon_inmessage_number_of_attachments;

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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (instancetype)initWithCoder:(NSCoder *)coder
{
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
