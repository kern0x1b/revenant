#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "../RevenantSayOnce.h"
#import <dlfcn.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static BOOL revenant_release_sends_attachments(void)
{
    return [MFMessageComposeViewController instancesRespondToSelector:@selector(addAttachmentData:typeIdentifier:filename:)];
}

static BOOL revenant_release_sends_subject(void)
{
    return [MFMessageComposeViewController instancesRespondToSelector:@selector(setSubject:)];
}

static BOOL revenant_release_knows_type(NSString *uti)
{
    return uti.length ? UTTypeConformsTo((__bridge CFStringRef)uti, CFSTR("public.data")) : NO;
}

static NSString *RevenantAttachmentKey(const char *symbol)
{
    NSString *const *constant = (NSString *const *)dlsym(RTLD_DEFAULT, symbol);
    return constant ? *constant : nil;
}

static BOOL revenant_release_exports_attachment_keys(void)
{
    return RevenantAttachmentKey("MFMessageComposeViewControllerAttachmentURL") != nil &&
           RevenantAttachmentKey("MFMessageComposeViewControllerAttachmentAlternateFilename") != nil;
}

static BOOL revenant_can_record_attachment(void)
{
    return [MFMessageComposeViewController canSendAttachments] && revenant_release_exports_attachment_keys();
}

static NSDictionary *RevenantAttachmentsOf(MFMessageComposeViewController *controller)
{
    return objc_getAssociatedObject(controller, @selector(attachments));
}

static void RevenantRecordAttachment(MFMessageComposeViewController *controller, NSString *name, id value)
{
    NSMutableDictionary *attachments = [RevenantAttachmentsOf(controller) mutableCopy] ?: [NSMutableDictionary dictionary];
    attachments[name] = value;
    objc_setAssociatedObject(controller, @selector(attachments), [attachments copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@interface MFMessageComposeViewController (Revenant7)
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *attachments;
@end

@implementation MFMessageComposeViewController (Revenant7)

@dynamic attachments;

+ (BOOL)canSendSubject
{
    return revenant_release_sends_subject();
}

+ (BOOL)canSendAttachments
{
    return revenant_release_sends_attachments();
}

+ (BOOL)isSupportedAttachmentUTI:(NSString *)uti
{
    return revenant_release_sends_attachments() && revenant_release_knows_type(uti);
}

- (BOOL)addAttachmentURL:(NSURL *)attachmentURL withAlternateFilename:(NSString *)alternateFilename
{
    if (!revenant_can_record_attachment() || !attachmentURL)
        return NO;
    RevenantRecordAttachment(self, alternateFilename.length ? alternateFilename : attachmentURL.lastPathComponent, attachmentURL);
    return YES;
}

- (BOOL)addAttachmentData:(NSData *)attachmentData typeIdentifier:(NSString *)uti filename:(NSString *)filename
{
    if (!revenant_can_record_attachment() || !attachmentData || ![self.class isSupportedAttachmentUTI:uti])
        return NO;
    RevenantRecordAttachment(self, filename.length ? filename : uti, attachmentData);
    return YES;
}

- (NSArray<NSDictionary *> *)attachments
{
    NSDictionary *held = RevenantAttachmentsOf(self);
    if (!held.count)
        return @[];
    NSString *urlKey = RevenantAttachmentKey("MFMessageComposeViewControllerAttachmentURL");
    NSString *nameKey = RevenantAttachmentKey("MFMessageComposeViewControllerAttachmentAlternateFilename");
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
    revenant_say_once_for(@"MFMessageComposeViewController.insertCollaborationItemProvider:",
                        @"RevenantMessageUI: this release's compose controller has no collaboration row, so the item provider "
                        @"is not inserted and the call answers NO.");
    return NO;
}

@end
