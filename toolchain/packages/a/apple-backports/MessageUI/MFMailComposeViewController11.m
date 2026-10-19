#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "../CharonSayOnce.h"

@implementation MFMailComposeViewController (Charon11)

- (void)setPreferredSendingEmailAddress:(NSString *)emailAddress
{
    [self setToRecipients:emailAddress.length ? @[emailAddress] : nil];
}

- (void)insertCollaborationItemProvider:(NSItemProvider *)itemProvider completionHandler:(void (^)(BOOL))completionHandler
{
    charon_say_once_for(@"MFMailComposeViewController.insertCollaborationItemProvider:completionHandler:",
                        @"CharonMessageUI: this release's mail composer has no collaboration row, so the item provider is "
                        @"not inserted and the completion handler is called with NO.");
    if (completionHandler)
        completionHandler(NO);
}

@end
