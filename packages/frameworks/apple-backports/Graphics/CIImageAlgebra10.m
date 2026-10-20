#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@implementation CIImage (RevenantAlgebra)

- (CIImage *)imageByApplyingGaussianBlurWithSigma:(CGFloat)sigma
{
    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blur setValue:self forKey:kCIInputImageKey];
    [blur setValue:@(sigma) forKey:@"inputRadius"];
    return blur.outputImage ?: self;
}

static NSString *const RevenantCIClampDepthKey = @"revenant.ciimage.clampDepth";

static NSInteger RevenantCIClampDepth(void)
{
    return [[[[NSThread currentThread] threadDictionary] objectForKey:RevenantCIClampDepthKey] integerValue];
}

static void RevenantSetCIClampDepth(NSInteger depth)
{
    [[[NSThread currentThread] threadDictionary] setObject:@(depth) forKey:RevenantCIClampDepthKey];
}

static CIImage *RevenantCIClamp(CIImage *image, CGRect rect)
{
    if (RevenantCIClampDepth() > 0)
        return image;
    RevenantSetCIClampDepth(RevenantCIClampDepth() + 1);
    CIImage *clamped = image;
    if (!CGRectIsNull(rect) && !CGRectIsEmpty(rect)) {
        CIFilter *filter = [CIFilter filterWithName:@"CIAffineClamp"];
        [filter setValue:[image imageByCroppingToRect:rect] forKey:kCIInputImageKey];
        clamped = filter.outputImage ?: [image imageByCroppingToRect:rect];
    }
    RevenantSetCIClampDepth(RevenantCIClampDepth() - 1);
    return clamped;
}

- (CIImage *)imageByClampingToExtent
{
    return RevenantCIClamp(self, self.extent);
}

- (CIImage *)imageByClampingToRect:(CGRect)rect
{
    return RevenantCIClamp(self, rect);
}

- (CIImage *)imageByInsertingIntermediate
{
    return [self imageByInsertingIntermediate:NO];
}

- (CIImage *)imageByInsertingIntermediate:(BOOL)cache
{
    CIFilter *filter = [CIFilter filterWithName:@"CIColorMatrix"];
    [filter setValue:self forKey:kCIInputImageKey];
    [filter setValue:[CIVector vectorWithX:1 Y:0 Z:0 W:0] forKey:@"inputRVector"];
    [filter setValue:[CIVector vectorWithX:0 Y:1 Z:0 W:0] forKey:@"inputGVector"];
    [filter setValue:[CIVector vectorWithX:0 Y:0 Z:1 W:0] forKey:@"inputBVector"];
    [filter setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:1] forKey:@"inputAVector"];
    return filter.outputImage ?: self;
}

- (CIImage *)imageByApplyingTransform:(CGAffineTransform)transform highQualityDownsample:(BOOL)highQualityDownsample
{
    if (!highQualityDownsample)
        return [self imageByApplyingTransform:transform];
    CGFloat scale = sqrtf(fabs(transform.a * transform.d - transform.b * transform.c));
    if (scale <= 0)
        return [self imageByApplyingTransform:transform];
    CIFilter *filter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
    [filter setValue:self forKey:kCIInputImageKey];
    [filter setValue:@(scale) forKey:@"inputScale"];
    [filter setValue:@(1) forKey:@"inputAspectRatio"];
    CIImage *scaled = filter.outputImage;
    if (!scaled)
        return [self imageByApplyingTransform:transform];
    CGAffineTransform rest = CGAffineTransformMakeTranslation(transform.tx, transform.ty);
    return [scaled imageByApplyingTransform:rest];
}

@end

@implementation CIImage (RevenantConstantColors)

- (CIImage *)revenant_imageOfColor:(CIColor *)color
{
    return [[CIImage alloc] initWithColor:color];
}

+ (CIImage *)blackImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0 green:0 blue:0 alpha:1]];
}

+ (CIImage *)whiteImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:1 green:1 blue:1 alpha:1]];
}

+ (CIImage *)grayImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0.5 green:0.5 blue:0.5 alpha:1]];
}

+ (CIImage *)redImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:1 green:0 blue:0 alpha:1]];
}

+ (CIImage *)greenImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0 green:1 blue:0 alpha:1]];
}

+ (CIImage *)blueImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0 green:0 blue:1 alpha:1]];
}

+ (CIImage *)cyanImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0 green:1 blue:1 alpha:1]];
}

+ (CIImage *)magentaImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:1 green:0 blue:1 alpha:1]];
}

+ (CIImage *)yellowImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:1 green:1 blue:0 alpha:1]];
}

+ (CIImage *)clearImage
{
    return [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0 green:0 blue:0 alpha:0]];
}

@end
