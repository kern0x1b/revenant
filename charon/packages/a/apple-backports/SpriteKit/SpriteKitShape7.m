// SpriteKitShape7.m - SKShapeNode of iOS 7, carried for the releases that have no SpriteKit at all.
//
// A shape is a node that draws a path, with a stroke and a fill and a line style. Its path is the one it is given, or the
// path of a rectangle, rounded rectangle, circle or ellipse, which the constructors build in the measured places: the
// rectangle and the ellipse at the origin they are given, and the sized forms centred on the origin (measured in
// facts/SpriteKit/SKShapeNode.md). The defaults are the host's: a white stroke of width 1, a clear fill, a bevel join, a
// butt cap and a miter limit of 0.5. Nothing here draws: the stroke and fill are the renderer's, which is owed.
#import "CharonSpriteKit.h"
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#endif

// A colour as the host keeps it when it is set: on the host the stroke and the fill are read back in the sRGB space (measured,
// facts/SpriteKit/SKShapeNode.md). The conversion is measured on macOS only; the iOS colour is stored as given.
static CharonSKColor *CharonSKSRGBColor(CharonSKColor *colour)
{
#if TARGET_OS_IPHONE
    return colour;
#else
    NSColor *converted = [colour colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    return converted != nil ? converted : colour;
#endif
}

// The path of a rectangle with its corners rounded by the radius, as a sequence of lines and quarter arcs. The radius is
// clamped to half the smaller side, so an oversized radius gives an ellipse-ended rectangle, not a broken path.
static CGPathRef CharonSKRoundedRectPath(CGRect rect, CGFloat radius)
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

// The path of a rectangle of the size, centred on the origin.
static CGRect CharonSKCentredRect(CGSize size)
{
    return CGRectMake(-size.width / 2, -size.height / 2, size.width, size.height);
}

@implementation SKShapeNode {
    CGPathRef _path;
    CharonSKColor *_strokeColor;
    CharonSKColor *_fillColor;
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
        _strokeColor = [CharonSKColor colorWithRed:1 green:1 blue:1 alpha:1];
        _fillColor = [CharonSKColor colorWithRed:0 green:0 blue:0 alpha:0];
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

// Centred shifts the path so that the centre of its bounding box is the origin (measured for a path at the origin).
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
    return [self shapeNodeWithRect:CharonSKCentredRect(size)];
}

+ (instancetype)shapeNodeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius
{
    CGPathRef path = CharonSKRoundedRectPath(rect, cornerRadius);
    SKShapeNode *node = [self shapeNodeWithPath:path];
    CGPathRelease(path);
    return node;
}

+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius
{
    return [self shapeNodeWithRect:CharonSKCentredRect(size) cornerRadius:cornerRadius];
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
    return [self shapeNodeWithEllipseInRect:CharonSKCentredRect(size)];
}

- (void)setStrokeColor:(CharonSKColor *)strokeColor
{
    _strokeColor = CharonSKSRGBColor(strokeColor);
}

- (void)setFillColor:(CharonSKColor *)fillColor
{
    _fillColor = CharonSKSRGBColor(fillColor);
}

- (CGPathRef)path
{
    return _path;
}

// The path is held: the node keeps its own reference, so the caller may release the path it gave.
- (void)setPath:(CGPathRef)path
{
    CGPathRef held = path == NULL ? NULL : CGPathRetain(path);
    if (_path != NULL) {
        CGPathRelease(_path);
    }
    _path = held;
}

@end
