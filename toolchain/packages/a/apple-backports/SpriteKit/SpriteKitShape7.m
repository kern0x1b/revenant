#import "RevenantSpriteKit.h"
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#endif

static RevenantSKColor *RevenantSKSRGBColor(RevenantSKColor *colour)
{
#if TARGET_OS_IPHONE
    return colour;
#else
    NSColor *converted = [colour colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    return converted != nil ? converted : colour;
#endif
}

static CGPathRef RevenantSKRoundedRectPath(CGRect rect, CGFloat radius)
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat limit = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect)) / 2;
    CGFloat r = MAX(0, MIN(radius, limit));
    CGPathMoveToPoint(path, NULL, CGRectGetMinX(rect) + r, CGRectGetMinY(rect));
    CGPathAddArcToPoint(path, NULL, CGRectGetMaxX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMinY(rect) + r, r);
    CGPathAddArcToPoint(path, NULL, CGRectGetMaxX(rect), CGRectGetMaxY(rect), CGRectGetMaxX(rect) - r, CGRectGetMaxY(rect), r);
    CGPathAddArcToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMaxY(rect), CGRectGetMinX(rect), CGRectGetMaxY(rect) - r, r);
    CGPathAddArcToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMinY(rect), CGRectGetMinX(rect) + r, CGRectGetMinY(rect), r);
    CGPathCloseSubpath(path);
    return path;
}

static CGRect RevenantSKCentredRect(CGSize size)
{
    return CGRectMake(-size.width / 2, -size.height / 2, size.width, size.height);
}

@implementation SKShapeNode {
    CGPathRef _path;
    RevenantSKColor *_strokeColor;
    RevenantSKColor *_fillColor;
    SKBlendMode _blendMode;
    BOOL _antialiased;
    CGFloat _lineWidth;
    CGFloat _glowWidth;
    CGLineCap _lineCap;
    CGLineJoin _lineJoin;
    CGFloat _miterLimit;
}

@synthesize strokeColor = _strokeColor;
@synthesize fillColor = _fillColor;
@synthesize blendMode = _blendMode;
@synthesize antialiased = _antialiased;
@synthesize lineWidth = _lineWidth;
@synthesize glowWidth = _glowWidth;
@synthesize lineCap = _lineCap;
@synthesize lineJoin = _lineJoin;
@synthesize miterLimit = _miterLimit;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _strokeColor = [RevenantSKColor colorWithRed:1 green:1 blue:1 alpha:1];
        _fillColor = [RevenantSKColor colorWithRed:0 green:0 blue:0 alpha:0];
        _antialiased = YES;
        _lineWidth = 1;
        _lineCap = kCGLineCapButt;
        _lineJoin = kCGLineJoinBevel;
        _miterLimit = 0.5;
    }
    return self;
}

- (void)dealloc
{
    if (_path != NULL) {
        CGPathRelease(_path);
    }
}

+ (instancetype)shapeNodeWithPath:(CGPathRef)path
{
    return [self shapeNodeWithPath:path centered:NO];
}

+ (instancetype)shapeNodeWithPath:(CGPathRef)path centered:(BOOL)centered
{
    SKShapeNode *node = [[self alloc] init];
    if (centered && path != NULL) {
        CGRect bounds = CGPathGetBoundingBox(path);
        CGAffineTransform shift = CGAffineTransformMakeTranslation(-CGRectGetMidX(bounds), -CGRectGetMidY(bounds));
        CGPathRef shifted = CGPathCreateCopyByTransformingPath(path, &shift);
        node.path = shifted;
        CGPathRelease(shifted);
    } else {
        node.path = path;
    }
    return node;
}

+ (instancetype)shapeNodeWithRect:(CGRect)rect
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, rect);
    SKShapeNode *node = [self shapeNodeWithPath:path];
    CGPathRelease(path);
    return node;
}

+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size
{
    return [self shapeNodeWithRect:RevenantSKCentredRect(size)];
}

+ (instancetype)shapeNodeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius
{
    CGPathRef path = RevenantSKRoundedRectPath(rect, cornerRadius);
    SKShapeNode *node = [self shapeNodeWithPath:path];
    CGPathRelease(path);
    return node;
}

+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius
{
    return [self shapeNodeWithRect:RevenantSKCentredRect(size) cornerRadius:cornerRadius];
}

+ (instancetype)shapeNodeWithCircleOfRadius:(CGFloat)radius
{
    return [self shapeNodeWithEllipseOfSize:CGSizeMake(2 * radius, 2 * radius)];
}

+ (instancetype)shapeNodeWithEllipseInRect:(CGRect)rect
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddEllipseInRect(path, NULL, rect);
    SKShapeNode *node = [self shapeNodeWithPath:path];
    CGPathRelease(path);
    return node;
}

+ (instancetype)shapeNodeWithEllipseOfSize:(CGSize)size
{
    return [self shapeNodeWithEllipseInRect:RevenantSKCentredRect(size)];
}

- (void)setStrokeColor:(RevenantSKColor *)strokeColor
{
    _strokeColor = RevenantSKSRGBColor(strokeColor);
}

- (void)setFillColor:(RevenantSKColor *)fillColor
{
    _fillColor = RevenantSKSRGBColor(fillColor);
}

- (CGPathRef)path
{
    return _path;
}

- (void)setPath:(CGPathRef)path
{
    CGPathRef held = path == NULL ? NULL : CGPathRetain(path);
    if (_path != NULL) {
        CGPathRelease(_path);
    }
    _path = held;
}

@end
