#import <AppKit/AppKit.h>

@interface SizedAttachment : NSTextAttachment
@end

@implementation SizedAttachment

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(CGRect)lineFragment glyphPosition:(CGPoint)position characterIndex:(NSUInteger)charIndex
{
    return CGRectMake(0, -2, 10, 12);
}

@end

static void report(NSString *name, NSTextAttachment *attachment)
{
    CGRect rect = [attachment attachmentBoundsForTextContainer:nil proposedLineFragment:CGRectMake(0, 0, 320, 20)
                                                  glyphPosition:CGPointZero characterIndex:0];
    printf("%s %g %g %g %g\n", name.UTF8String, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

int main(void)
{
    @autoreleasepool {
        NSTextAttachment *set = [[NSTextAttachment alloc] init];
        set.bounds = CGRectMake(1, 2, 30, 40);
        report(@"bounds set", set);

        NSTextAttachment *image = [[NSTextAttachment alloc] init];
        image.image = [[NSImage alloc] initWithSize:NSMakeSize(10, 20)];
        report(@"image only", image);

        NSTextAttachment *both = [[NSTextAttachment alloc] init];
        both.image = [[NSImage alloc] initWithSize:NSMakeSize(10, 20)];
        both.bounds = CGRectMake(0, 0, 5, 6);
        report(@"bounds over image", both);

        NSTextAttachment *sized = [[SizedAttachment alloc] init];
        sized.image = [[NSImage alloc] initWithSize:NSMakeSize(10, 20)];
        report(@"subclass override", sized);
    }
    return 0;
}
