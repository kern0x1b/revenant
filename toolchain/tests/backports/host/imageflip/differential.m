#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import <objc/message.h>

void host_attach_prefixed(const char *prefix);

static int failures, checks;

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

static UIImage *flipped(UIImage *image, BOOL ours)
{
    SEL flip = ours ? NSSelectorFromString(@"charonHost_imageWithHorizontallyFlippedOrientation") : @selector(imageWithHorizontallyFlippedOrientation);
    return ((UIImage * (*)(id, SEL))objc_msgSend)(image, flip);
}

static NSString *describe(UIImage *image, UIImage *original)
{
    return [NSString stringWithFormat:@"orientation %ld, size %@, scale %g, same pixels %d, caps %@, resizing %ld, alignment %@, rendering %ld, frames %lu, duration %g, distinct %d",
                                      (long)image.imageOrientation, NSStringFromCGSize(image.size), image.scale,
                                      image.CGImage == original.CGImage, NSStringFromUIEdgeInsets(image.capInsets), (long)image.resizingMode,
                                      NSStringFromUIEdgeInsets(image.alignmentRectInsets), (long)image.renderingMode,
                                      (unsigned long)image.images.count, image.duration, image != original];
}

static CGImageRef make_pixels(int width, int height)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width / 2, height));
    CGImageRef pixels = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return pixels;
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        CGImageRef pixels = make_pixels(8, 4);
        for (NSInteger orientation = 0; orientation < 8; orientation++) {
            UIImage *image = [UIImage imageWithCGImage:pixels scale:2 orientation:(UIImageOrientation)orientation];
            compare([NSString stringWithFormat:@"orientation %ld", (long)orientation], describe(flipped(image, NO), image), describe(flipped(image, YES), image));
            UIImage *twice = flipped(flipped(image, YES), YES);
            compare([NSString stringWithFormat:@"orientation %ld flipped twice comes back", (long)orientation],
                    [NSString stringWithFormat:@"%ld", (long)image.imageOrientation], [NSString stringWithFormat:@"%ld", (long)twice.imageOrientation]);
        }
        UIImage *base = [UIImage imageWithCGImage:pixels scale:1 orientation:UIImageOrientationLeft];
        UIImage *resizable = [base resizableImageWithCapInsets:UIEdgeInsetsMake(1, 2, 1, 2) resizingMode:UIImageResizingModeTile];
        compare(@"a resizable image", describe(flipped(resizable, NO), resizable), describe(flipped(resizable, YES), resizable));
        UIImage *aligned = [base imageWithAlignmentRectInsets:UIEdgeInsetsMake(1, 0, 2, 0)];
        compare(@"an image with alignment insets", describe(flipped(aligned, NO), aligned), describe(flipped(aligned, YES), aligned));
        UIImage *template = [base imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        compare(@"a template image", describe(flipped(template, NO), template), describe(flipped(template, YES), template));
        UIImage *all = [[[base resizableImageWithCapInsets:UIEdgeInsetsMake(1, 1, 1, 1)] imageWithAlignmentRectInsets:UIEdgeInsetsMake(0, 1, 0, 1)]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        compare(@"an image with everything", describe(flipped(all, NO), all), describe(flipped(all, YES), all));
        UIImage *frames = [UIImage animatedImageWithImages:@[base, [UIImage imageWithCGImage:pixels]] duration:0.5];
        compare(@"an animated image", describe(flipped(frames, NO), frames), describe(flipped(frames, YES), frames));
        UIImage *core = [UIImage imageWithCIImage:[CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0]] scale:2 orientation:UIImageOrientationDown];
        compare(@"a Core Image image", describe(flipped(core, NO), core), describe(flipped(core, YES), core));
        UIImage *empty = [[UIImage alloc] init];
        compare(@"an image with no pixels, whose orientation the backport does not carry",
                [NSString stringWithFormat:@"size %@, no pixels %d", NSStringFromCGSize(flipped(empty, NO).size), flipped(empty, NO).CGImage == NULL],
                [NSString stringWithFormat:@"size %@, no pixels %d", NSStringFromCGSize(flipped(empty, YES).size), flipped(empty, YES).CGImage == NULL]);
        CGImageRelease(pixels);
        printf("%d checks, %d failures\n", checks, failures);
        return failures;
    }
}
