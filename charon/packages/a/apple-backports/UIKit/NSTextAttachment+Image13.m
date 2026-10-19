#import <UIKit/UIKit.h>

// +[NSTextAttachment textAttachmentWithImage:] is iOS 13, and the release's own NSTextAttachment
// already has everything it needs: -image and -setImage: are in its selector table on 6.1.3
// (objc.inventory, UIFoundation), and the SDK's header dates them iOS 7.0. So this is one
// initializer and one property write on the class the release already provides, which is why it
// is a category and not a re-implementation: NSTextAttachment is not the port's class.
@implementation NSTextAttachment (CharonImage13)

// A send, not a dot-syntax write: -image is declared NS_NONATOMIC_IOSONLY, so `attachment.image
// = image` does not compile on iOS, and the property name and the setter are one selector here.
+ (NSTextAttachment *)textAttachmentWithImage:(UIImage *)image
{
    // -initWithData:ofType: is the release's own designated initializer and its header says both
    // arguments may be nil, which is exactly the "attachment without document contents" case the
    // header describes for an attachment that carries an image instead of file data.
    NSTextAttachment *attachment = [[self alloc] initWithData:nil ofType:nil];
    [attachment setImage:image];
    return attachment;
}

@end