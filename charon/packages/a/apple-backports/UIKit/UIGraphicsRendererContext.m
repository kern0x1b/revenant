#import "CharonGraphicsRenderer.h"

@implementation UIGraphicsRendererContext {
@private
    CGContextRef _context;
    UIGraphicsRendererFormat *_format;
    BOOL _createsImages;
}

- (instancetype)initWithCGContext:(CGContextRef)context format:(UIGraphicsRendererFormat *)format
{
    if ((self = [super init])) {
        _context = context;
        _format = [format copy];
    }
    return self;
}

- (CGContextRef)CGContext
{
    return _context;
}

- (UIGraphicsRendererFormat *)format
{
    return _format;
}

- (BOOL)__createsImages
{
    return _createsImages;
}

- (void)set__createsImages:(BOOL)createsImages
{
    _createsImages = createsImages;
}

- (void)fillRect:(CGRect)rect
{
    [self fillRect:rect blendMode:kCGBlendModeNormal];
}

- (void)fillRect:(CGRect)rect blendMode:(CGBlendMode)blendMode
{
    CGContextRef context = self.CGContext;
    CGBlendMode previous = CGContextGetBlendMode(context);
    if (blendMode != previous)
        CGContextSetBlendMode(context, blendMode);
    CGContextFillRect(context, rect);
    if (blendMode != previous)
        CGContextSetBlendMode(context, previous);
}

- (void)strokeRect:(CGRect)rect
{
    [self strokeRect:rect blendMode:kCGBlendModeNormal];
}

- (void)strokeRect:(CGRect)rect blendMode:(CGBlendMode)blendMode
{
    CGContextRef context = self.CGContext;
    CGBlendMode previous = CGContextGetBlendMode(context);
    CGFloat width = CGContextGetLineWidth(context);
    if (blendMode != previous)
        CGContextSetBlendMode(context, blendMode);
    CGContextStrokeRect(context, CGRectInset(rect, width * 0.5, width * 0.5));
    if (blendMode != previous)
        CGContextSetBlendMode(context, previous);
    CGContextSetLineWidth(context, width);
}

- (void)clipToRect:(CGRect)rect
{
    CGContextClipToRect(self.CGContext, rect);
}

@end
