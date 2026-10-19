#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "../CharonSayOnce.h"
#import <dlfcn.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// What the release's own compose controller can carry, read off its own metadata rather than
// assumed: iOS 7 is where -addAttachmentData:typeIdentifier:filename: and the subject field arrived,
// so a controller that has neither has nowhere to put either. Both questions below are answered from
// that, so the answers follow the release rather than this file.

static BOOL charon_release_sends_attachments(void)
{
    return [MFMessageComposeViewController instancesRespondToSelector:@selector(addAttachmentData:typeIdentifier:filename:)];
}

static BOOL charon_release_sends_subject(void)
{
    return [MFMessageComposeViewController instancesRespondToSelector:@selector(setSubject:)];
}

// A type the release's own store knows: UTTypeConformsTo answers for an identifier it holds a record
// for, and is public from iOS 3 to 14.
static BOOL charon_release_knows_type(NSString *uti)
{
    return uti.length ? UTTypeConformsTo((__bridge CFStringRef)uti, CFSTR("public.data")) : NO;
}

// The two keys of the attachments array are the release's own constants, and they are the array's
// contract: an application reads MFMessageComposeViewControllerAttachmentURL out of each dictionary it
// is given. This release exports neither symbol (measured against the armv7 6.1.3 cache with
// dump-cache.lua, and the two names are absent from it), so a dictionary the port built would carry
// keys of its own making and nothing could read it back. So the keys are asked of the release at run
// time, and an attachment is not recorded unless the release really has both.
static NSString *CharonAttachmentKey(const char *symbol)
{
    // The release's own constant, reached through the symbol the release exports for it, so the key
    // is the release's string and not this file's spelling of it.
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

// The property is declared again here, widened where the header has it readonly, because @dynamic in
// a category needs a declaration of its own to answer to; the accessor below is the one the release's
// class and this category share.
//
// What is NOT here is as deliberate. -disableUserAttachments hides affordances this release's compose
// sheet does not have, so there is nothing to hide; subject names a field the release's composer does
// not have and its Messages sends no MMS, so a subject can be neither shown nor sent; and
// -setUPIVerificationCodeSendCompletion: belongs to the one-time-code detection in the system Messages
// app, which is a service this release has no path to. A selector the port carried for any of those
// would be one that stores a value nothing can act on - the silent fake COORDINATION.md §2 forbids -
// so they are registry entries with status absent, and the header's own +canSendSubject,
// +canSendAttachments are what an application reads to find out.
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

// The composer this release has has no attachment row, so an attachment is never added and the array
// below stays empty. The answers are the header's own - NO - reached through +canSendAttachments,
// not a constant and not a fabricated YES.
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
    // What the controller holds, one dictionary per attachment, each carrying the two keys the
    // release's own constants name. Empty here, and empty for a reason: neither add method records
    // anything on this release.
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

// The composer this release has has no row a collaboration attachment could go into: the document
// interaction came later, and the release has no such view to insert one into.
- (BOOL)insertCollaborationItemProvider:(NSItemProvider *)itemProvider
{
    charon_say_once_for(@"MFMessageComposeViewController.insertCollaborationItemProvider:",
                        @"CharonMessageUI: this release's compose controller has no collaboration row, so the item provider "
                        @"is not inserted and the call answers NO.");
    return NO;
}

@end
