#import "CharonGraphicsRenderer.h"

@implementation UIGraphicsImageRendererFormat {
@private
    CGFloat _scale;
    BOOL _opaque;
    UIGraphicsImageRendererFormatRange _preferredRange;
}

+ (instancetype)defaultFormat
{
    UIGraphicsImageRendererFormat *format = [super defaultFormat];
    format.prefersExtendedRange = NO;
    format.opaque = NO;
    format.scale = [UIScreen mainScreen].scale;
    return format;
}

- (instancetype)init
{
    if ((self = [super init]))
        _scale = [UIScreen mainScreen].scale;
    return self;
}

- (CGFloat)scale
{
    return _scale;
}

- (void)setScale:(CGFloat)scale
{
    _scale = scale;
}

- (BOOL)opaque
{
    return _opaque;
}

- (void)setOpaque:(BOOL)opaque
{
    _opaque = opaque;
}

// The deprecated flag is the range: YES makes the range extended; NO takes an extended range down to standard and leaves the others alone.
// The host behaves so (tests/backports/host/storage-config).
- (BOOL)prefersExtendedRange
{
    return _preferredRange == UIGraphicsImageRendererFormatRangeExtended;
}

- (void)setPrefersExtendedRange:(BOOL)prefersExtendedRange
{
    if (prefersExtendedRange)
        _preferredRange = UIGraphicsImageRendererFormatRangeExtended;
    else if (_preferredRange == UIGraphicsImageRendererFormatRangeExtended)
        _preferredRange = UIGraphicsImageRendererFormatRangeStandard;
}

// The range is kept as set; the host answers automatic (0) by default and keeps what it is given (tests/backports/host/storage-config).
- (UIGraphicsImageRendererFormatRange)preferredRange
{
    return _preferredRange;
}

- (void)setPreferredRange:(UIGraphicsImageRendererFormatRange)preferredRange
{
    _preferredRange = preferredRange;
}

- (CGFloat)_contextScale
{
    return _scale != 0 ? _scale : [UIScreen mainScreen].scale;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIGraphicsImageRendererFormat *copy = [super copyWithZone:zone];
    copy.opaque = self.opaque;
    copy.scale = self.scale;
    copy.prefersExtendedRange = self.prefersExtendedRange;
    copy.preferredRange = self.preferredRange;
    return copy;
}

@end
