#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "../CharonSayOnce.h"
#import <dlfcn.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static BOOL charon_release_sends_attachments(void)
{
    return [MFMessageComposeViewController instancesRespondToSelector:@selector(addAttachmentData:typeIdentifier:filename:)];
}

static BOOL charon_release_sends_subject(void)
{
    return [MFMessageComposeViewController instancesRespondToSelector:@selector(setSubject:)];
}

static BOOL charon_release_knows_type(NSString *uti)
{
    return uti.length ? UTTypeConformsTo((__bridge CFStringRef)uti, CFSTR("public.data")) : NO;
}

static NSString *CharonAttachmentKey(const char *symbol)
{
    NSString *const *constant = (NSString *const *)dlsym(RTLD_DEFAULT, symbol);
    return constant ? *constant : nil;
}

static BOOL charon_release_exports_attachment_keys(void)
{
    return CharonAttachmentKey("MFMessageComposeViewControllerAttachmentURL") != nil &&
           CharonAttachmentKey("MFMessageComposeViewControllerAttachmentAlternateFilename") != nil;
}

static BOOL charon_can_record_attachment(void)
{
    return [MFMessageComposeViewController canSendAttachments] && charon_release_exports_attachment_keys();
}

static NSDictionary *CharonAttachmentsOf(MFMessageComposeViewController *controller)
{
    return objc_getAssociatedObject(controller, @selector(attachments));
}

static void CharonRecordAttachment(MFMessageComposeViewController *controller, NSString *name, id value)
{
    NSMutableDictionary *attachments = [CharonAttachmentsOf(controller) mutableCopy] ?: [NSMutableDictionary dictionary];
    attachments[name] = value;
    objc_setAssociatedObject(controller, @selector(attachments), [attachments copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@interface MFMessageComposeViewController (Charon7)
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *attachments;
@end

@implementation MFMessageComposeViewController (Charon7)

@dynamic attachments;

+ (BOOL)canSendSubject
{
    return charon_release_sends_subject();
}

+ (BOOL)canSendAttachments
{
    return charon_release_sends_attachments();
}

+ (BOOL)isSupportedAttachmentUTI:(NSString *)uti
{
    return charon_release_sends_attachments() && charon_release_knows_type(uti);
}

- (BOOL)addAttachmentURL:(NSURL *)attachmentURL withAlternateFilename:(NSString *)alternateFilename
{
    if (!charon_can_record_attachment() || !attachmentURL)
        return NO;
    CharonRecordAttachment(self, alternateFilename.length ? alternateFilename : attachmentURL.lastPathComponent, attachmentURL);
    return YES;
}

- (BOOL)addAttachmentData:(NSData *)attachmentData typeIdentifier:(NSString *)uti filename:(NSString *)filename
{
    if (!charon_can_record_attachment() || !attachmentData || ![self.class isSupportedAttachmentUTI:uti])
        return NO;
    CharonRecordAttachment(self, filename.length ? filename : uti, attachmentData);
    return YES;
}

- (NSArray<NSDictionary *> *)attachments
{
    NSDictionary *held = CharonAttachmentsOf(self);
    if (!held.count)
        return @[];
    NSString *urlKey = CharonAttachmentKey("MFMessageComposeViewControllerAttachmentURL");
    NSString *nameKey = CharonAttachmentKey("MFMessageComposeViewControllerAttachmentAlternateFilename");
    if (!urlKey || !nameKey)
        return @[];
    NSMutableArray *attachments = [NSMutableArray array];
    [held enumerateKeysAndObjectsUsingBlock:^(NSString *name, id value, BOOL *stop) {
        [attachments addObject:@{urlKey: value, nameKey: name}];
    }];
    return [attachments copy];
}

- (BOOL)insertCollaborationItemProvider:(NSItemProvider *)itemProvider
{
    charon_say_once_for(@"MFMessageComposeViewController.insertCollaborationItemProvider:",
                        @"CharonMessageUI: this release's compose controller has no collaboration row, so the item provider "
                        @"is not inserted and the call answers NO.");
    return NO;
}

@end
