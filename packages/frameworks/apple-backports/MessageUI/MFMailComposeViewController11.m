#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "../RevenantSayOnce.h"

@implementation MFMailComposeViewController (Revenant11)

- (void)setPreferredSendingEmailAddress:(NSString *)emailAddress
{
    [self setToRecipients:emailAddress.length ? @[emailAddress] : nil];
}

- (void)insertCollaborationItemProvider:(NSItemProvider *)itemProvider completionHandler:(void (^)(BOOL))completionHandler
{
    revenant_say_once_for(@"MFMailComposeViewController.insertCollaborationItemProvider:completionHandler:",
                        @"RevenantMessageUI: this release's mail composer has no collaboration row, so the item provider is "
                        @"not inserted and the completion handler is called with NO.");
    if (completionHandler)
        completionHandler(NO);
}

@end
