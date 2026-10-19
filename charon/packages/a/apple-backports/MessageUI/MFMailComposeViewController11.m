#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "../CharonSayOnce.h"

// The address the sender would rather send from. The release's mail composer has one To: field the
// user may edit, which is the field this API writes into, so the address is put there for real
// instead of being remembered and dropped.

@implementation MFMailComposeViewController (Charon11)

- (void)setPreferredSendingEmailAddress:(NSString *)emailAddress
{
    [self setToRecipients:emailAddress.length ? @[emailAddress] : nil];
}

// The release's mail composer has no collaboration row: the document interaction that shows one came
// later, so there is nowhere to put the provider and the completion is told the truth about it.
- (void)insertCollaborationItemProvider:(NSItemProvider *)itemProvider completionHandler:(void (^)(BOOL))completionHandler
{
    charon_say_once_for(@"MFMailComposeViewController.insertCollaborationItemProvider:completionHandler:",
                        @"CharonMessageUI: this release's mail composer has no collaboration row, so the item provider is "
                        @"not inserted and the completion handler is called with NO.");
    if (completionHandler)
        completionHandler(NO);
}

@end
