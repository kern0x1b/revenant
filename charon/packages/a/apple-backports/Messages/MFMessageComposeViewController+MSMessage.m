#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <Messages/MSMessage.h>
#import <objc/runtime.h>

// The message the SMS compose controller is given, and the one it is read back from. It is a value
// property: Apple's own abstract for it is one line - "This property sets the initial interactive
// message" - and a value property's whole contract is that what is given is what is read back, which
// is what the copy below does.
//
// What the release cannot do is make the message interactive. iOS 6.1.3's Messages app sends a text
// message and has no iMessage, no interactive bubble, no URL payload and no session ordering, and the
// release's own MFMessageComposeViewController has no notion of an MSMessage at all (measured in its
// armv7 6.1.3 ObjC metadata). So the message is kept and handed back, and the session, URL, layout and
// captions it carries are the values the headers promise - they travel with a copy and survive an
// archive - while the sheet the user sees is the release's own text-message sheet, which is the same
// truth +canSendSubject and +canSendAttachments already report. What the message can never be is
// sent: MSMessage.isPending answers YES for as long as the port holds it, because a message leaves
// through -[MSConversation insertMessage:completionHandler:] and this release has no conversation.

// The property is declared again here because @dynamic in a category needs a declaration of its own to
// answer to; the accessors below are the ones, and the value lives in an associated object because the
// release's class has no ivar of ours to put it in.
@interface MFMessageComposeViewController (CharonMSMessage)
@property (nonatomic, copy, nullable) MSMessage *message;
@end

@implementation MFMessageComposeViewController (CharonMSMessage)

@dynamic message;

- (MSMessage *)message
{
    MSMessage *message = objc_getAssociatedObject(self, @selector(message));
    if (message)
        return message;
    // Never given one: a fresh message, with what the release's own composer already holds in it, so
    // an application that reads the property before setting it gets a message and not nil.
    message = [[MSMessage alloc] init];
    message.summaryText = self.body;
    return message;
}

- (void)setMessage:(MSMessage *)message
{
    objc_setAssociatedObject(self, @selector(message), message, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
