#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <Messages/MSMessage.h>
#import <objc/runtime.h>

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
    message = [[MSMessage alloc] init];
    message.summaryText = self.body;
    return message;
}

- (void)setMessage:(MSMessage *)message
{
    objc_setAssociatedObject(self, @selector(message), message, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
