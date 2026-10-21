#import <UIKit/UIKit.h>

@implementation NSAttributedString (RevenantAttachments9)

- (BOOL)containsAttachmentsInRange:(NSRange)range
{
    __block BOOL found = NO;
    [self enumerateAttribute:NSAttachmentAttributeName inRange:range options:0 usingBlock:^(id value, NSRange runRange, BOOL *stop) {
        if (value) {
            found = YES;
            *stop = YES;
        }
    }];
    return found;
}

@end
