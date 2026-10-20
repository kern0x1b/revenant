#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#define RevenantCtxContext RevenantGOCtxContext

@interface RevenantCtxContext : CIContext
- (instancetype)initWithContext:(CIContext *)context cgContext:(CGContextRef)cgctx options:(NSDictionary *)options;
- (CGContextRef)revenant_drawingContext;
@end

@implementation RevenantCtxContext {
    CGContextRef _cgctx;
    NSDictionary *_options;
}

- (instancetype)initWithContext:(CIContext *)context cgContext:(CGContextRef)cgctx options:(NSDictionary *)options
{
    (void)context;
    if ((self = [super initWithOptions:options.count ? options : @{
        kCIContextWorkingColorSpace: [NSNull null]
    }])) {
        _cgctx = cgctx;
        _options = options ?: @{};
    }
    return self;
}

- (CGContextRef)revenant_drawingContext
{
    return _cgctx;
}

- (CGColorSpaceRef)workingColorSpace
{
    id space = _options[kCIContextWorkingColorSpace];
    return [space isKindOfClass:[NSNull class]] || !space ? NULL : (__bridge CGColorSpaceRef)space;
}

- (CIFormat)workingFormat
{
    id format = _options[kCIContextWorkingFormat];
    return [format isKindOfClass:[NSNumber class]] ? (CIFormat)[format unsignedIntValue] : kCIFormatRGBA8;
}

- (void)drawImage:(CIImage *)image inRect:(CGRect)inRect fromRect:(CGRect)fromRect
{
    if (!_cgctx || !image)
        return;
    CGImageRef made = [self createCGImage:image fromRect:fromRect format:kCIFormatRGBA8 colorSpace:NULL deferred:NO];
    if (!made)
        return;
    CGContextSaveGState(_cgctx);
    CGContextDrawImage(_cgctx, inRect, made);
    CGContextRestoreGState(_cgctx);
    CGImageRelease(made);
}

@end

@implementation CIContext (RevenantGCOwner)

+ (instancetype)contextWithCGContext:(CGContextRef)cgctx options:(NSDictionary *)options
{
    return [[RevenantCtxContext alloc] initWithContext:nil cgContext:cgctx options:options ?: @{}];
}

@end
