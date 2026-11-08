#import "RevenantMetal.h"

@implementation RevenantMetalDevice (LinearTextureAlignment11)

- (NSUInteger)minimumLinearTextureAlignmentForPixelFormat:(MTLPixelFormat)format
{
    NSUInteger texel = RevenantMetalTexelBytes(format);
    if (!texel)
        [NSException raise:NSInvalidArgumentException format:@"minimumLinearTextureAlignmentForPixelFormat: pixel format %lu has no linear texture on this device", (unsigned long)format];
    return texel;
}

@end
