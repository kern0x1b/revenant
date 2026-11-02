#include "../revenant_impl.h"
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>

NSData *BACKPORT_IMPL(UIImageHEICRepresentation)(UIImage *image)
{
    CGImageRef core = image.CGImage;
    if (!core)
        return nil;
    NSMutableData *written = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)written, CFSTR("public.heic"), 1, NULL);
    if (!destination)
        return nil;
    CGImageDestinationAddImage(destination, core, NULL);
    BOOL finished = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return finished ? written : nil;
}
