#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <string.h>

// The drawing the backport replaces, kept by the replacement, and the replacement itself, which is what -drawAtPoint: now
// calls. On the host, the kept implementation is macOS's own, which honours NSBaselineOffsetAttributeName, so it is the oracle.
extern IMP revenant_baseline_draw_at_point_original;

static const NSInteger width = 240;
static const NSInteger height = 80;

static NSData *render(NSAttributedString *text, BOOL replaced)
{
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height
                                                                 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
                                                                colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    NSPoint origin = NSMakePoint(20, 20);
    if (replaced)
        [text drawAtPoint:origin];
    else
        ((void (*)(id, SEL, NSPoint))revenant_baseline_draw_at_point_original)(text, @selector(drawAtPoint:), origin);
    [NSGraphicsContext restoreGraphicsState];
    return [NSData dataWithBytes:rep.bitmapData length:rep.bytesPerRow * height];
}

static NSUInteger ink(NSData *pixels)
{
    const unsigned char *bytes = pixels.bytes;
    NSUInteger count = 0;
    for (NSUInteger index = 3; index < pixels.length; index += 4) {
        if (bytes[index] != 0)
            count++;
    }
    return count;
}

static NSAttributedString *text(CGFloat offset)
{
    NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:24]};
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:@"Hxg" attributes:attributes];
    if (offset != 0)
        [string addAttribute:NSBaselineOffsetAttributeName value:@(offset) range:NSMakeRange(0, string.length)];
    return string;
}

int main(void)
{
    @autoreleasepool {
        NSData *nativePlain = render(text(0), NO);
        NSData *backportPlain = render(text(0), YES);
        NSData *nativeRaised = render(text(6), NO);
        NSData *backportRaised = render(text(6), YES);
        NSData *nativeOffsetIgnored = render(text(0), NO);

        BOOL plainEqual = [nativePlain isEqualToData:backportPlain];
        BOOL raisedEqual = [nativeRaised isEqualToData:backportRaised];
        BOOL negativeDiffers = ![nativeRaised isEqualToData:nativeOffsetIgnored];
        BOOL offsetApplied = ink(nativeRaised) > 0 && ![backportRaised isEqualToData:backportPlain];
        printf("BASELINE-ORACLE plain-equal=%d raised-equal=%d offset-applied=%d negative-differs=%d ink=%lu\n",
               plainEqual, raisedEqual, offsetApplied, negativeDiffers, (unsigned long)ink(backportRaised));
        return plainEqual && raisedEqual && offsetApplied && negativeDiffers ? 0 : 1;
    }
}
