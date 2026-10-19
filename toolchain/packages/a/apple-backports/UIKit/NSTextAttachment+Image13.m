#import <UIKit/UIKit.h>

@implementation NSTextAttachment (RevenantImage13)

+ (NSTextAttachment *)textAttachmentWithImage:(UIImage *)image
{
    NSTextAttachment *attachment = [[self alloc] initWithData:nil ofType:nil];
    [attachment setImage:image];
    return attachment;
}

@end
