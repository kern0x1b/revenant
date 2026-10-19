// MKOverlayPathRenderer: the fill and stroke of a shape, on top of the coordinate arithmetic of
// MKOverlayRenderer. This is where MapKit's own path renderers are built, so the line defaults
// here are the ones the iOS 7 header documents: a line width of 0 means the road width at the
// current zoom scale (MKRoadWidthAtZoomScale, the release's own function, which has been in
// MapKit.framework since iOS 4.0), round joins and caps, a miter limit of 10 and no dashes.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import "CharonMapKit.h"

@implementation MKOverlayPathRenderer {
    UIColor *_fillColor;
    UIColor *_strokeColor;
    CGFloat _lineWidth;
    CGLineJoin _lineJoin;
    CGLineCap _lineCap;
    CGFloat _miterLimit;
    CGFloat _lineDashPhase;
    NSArray<NSNumber *> *_lineDashPattern;
    BOOL _shouldRasterize;
    CGPathRef _path;
}

@synthesize fillColor = _fillColor;
@synthesize strokeColor = _strokeColor;
@synthesize lineWidth = _lineWidth;
@synthesize lineJoin = _lineJoin;
@synthesize lineCap = _lineCap;
@synthesize miterLimit = _miterLimit;
@synthesize lineDashPhase = _lineDashPhase;
@synthesize lineDashPattern = _lineDashPattern;
@synthesize shouldRasterize = _shouldRasterize;

- (instancetype)initWithOverlay:(id <MKOverlay>)overlay
{
    self = [super initWithOverlay:overlay];
    if (self) {
        _lineWidth = 0.0;
        _lineJoin = kCGLineJoinRound;
        _lineCap = kCGLineCapRound;
        _miterLimit = 10.0;
        _lineDashPhase = 0.0;
        _lineDashPattern = nil;
        _shouldRasterize = NO;
        _fillColor = nil;
        _strokeColor = nil;
        _path = NULL;
    }
    return self;
}

- (void)dealloc
{
    [self invalidatePath];
}

// The shape's own path, in the renderer's point space. Subclasses answer by overriding
// -createPath and assigning the path they build to self.path, which is the header's own extension
// point; a path renderer whose subclass builds nothing draws nothing, which is the shape-less
// renderer's honest answer rather than an empty stroke.
- (void)createPath
{
}

- (CGPathRef)path
{
    if (!_path) {
        [self createPath];
    }
    return _path;
}

- (void)setPath:(CGPathRef)path
{
    if (_path == path) {
        return;
    }
    if (_path) {
        CGPathRelease(_path);
    }
    _path = path ? CGPathRetain(path) : NULL;
}

- (void)invalidatePath
{
    if (_path) {
        CGPathRelease(_path);
        _path = NULL;
    }
}

- (CGFloat)charon_lineWidthAtZoomScale:(MKZoomScale)zoomScale
{
    if (_lineWidth > 0.0) {
        return _lineWidth;
    }
    // The release's own road width at this zoom scale, which is what a line width of 0 means.
    return MAX(MKRoadWidthAtZoomScale(zoomScale), 1.0);
}

- (void)applyStrokePropertiesToContext:(CGContextRef)context atZoomScale:(MKZoomScale)zoomScale
{
    CGContextSetLineWidth(context, (CGFloat)[self charon_lineWidthAtZoomScale:zoomScale]);
    CGContextSetLineJoin(context, _lineJoin);
    CGContextSetLineCap(context, _lineCap);
    CGContextSetMiterLimit(context, (CGFloat)_miterLimit);
    if (_lineDashPattern && _lineDashPattern.count > 0) {
        NSUInteger count = _lineDashPattern.count;
        CGFloat *dashes = (CGFloat *)malloc(sizeof(CGFloat) * count);
        if (dashes) {
            for (NSUInteger index = 0; index < count; index++) {
                CGFloat value = (CGFloat)[_lineDashPattern[index] doubleValue];
                dashes[index] = value > 0.0 ? value : 0.0;
            }
            CGContextSetLineDash(context, (CGFloat)_lineDashPhase, dashes, count);
            free(dashes);
        }
    } else {
        CGContextSetLineDash(context, 0.0, NULL, 0);
    }
}

- (void)applyFillPropertiesToContext:(CGContextRef)context atZoomScale:(MKZoomScale)zoomScale
{
    [_fillColor setFill];
}

- (void)strokePath:(CGPathRef)path inContext:(CGContextRef)context
{
    if (!path || !context) {
        return;
    }
    if (!self.strokeColor) {
        return;
    }
    CGContextSaveGState(context);
    [self applyStrokePropertiesToContext:context atZoomScale:[self charon_zoomScale]];
    [self.strokeColor setStroke];
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

- (void)fillPath:(CGPathRef)path inContext:(CGContextRef)context
{
    if (!path || !context) {
        return;
    }
    if (!self.fillColor) {
        return;
    }
    CGContextSaveGState(context);
    [self applyFillPropertiesToContext:context atZoomScale:[self charon_zoomScale]];
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
}

// shouldRasterize is the header's own switch between drawing the shape as vector geometry and
// compositing it as a bitmap. It is real here: YES renders the path once into a bitmap at the
// screen's own scale and draws that image, which is what the release's map view does with a
// rasterized overlay, and NO strokes and fills the path itself.
- (void)charon_drawRasterizedInContext:(CGContextRef)context zoomScale:(MKZoomScale)zoomScale
{
    CGPathRef path = self.path;
    if (!path) {
        return;
    }
    CGRect box = CGPathGetBoundingBox(path);
    if (CGRectIsNull(box) || CGRectIsEmpty(box)) {
        return;
    }
    CGFloat scale = self.contentScaleFactor;
    size_t width = (size_t)ceil(CGRectGetWidth(box) * scale);
    size_t height = (size_t)ceil(CGRectGetHeight(box) * scale);
    if (width == 0 || height == 0 || width > 8192 || height > 8192) {
        return;
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    if (!space) {
        return;
    }
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
                                                kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(space);
    if (!bitmap) {
        return;
    }
    CGContextScaleCTM(bitmap, scale, scale);
    CGContextTranslateCTM(bitmap, -CGRectGetMinX(box), -CGRectGetMinY(box));
    if (self.fillColor) {
        [self applyFillPropertiesToContext:bitmap atZoomScale:zoomScale];
        CGContextAddPath(bitmap, path);
        CGContextFillPath(bitmap);
    }
    if (self.strokeColor) {
        [self applyStrokePropertiesToContext:bitmap atZoomScale:zoomScale];
        [self.strokeColor setStroke];
        CGContextAddPath(bitmap, path);
        CGContextStrokePath(bitmap);
    }
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    if (image) {
        CGContextDrawImage(context, box, image);
        CGImageRelease(image);
    }
}

- (void)charon_drawInContext:(CGContextRef)context zoomScale:(MKZoomScale)zoomScale mapRect:(MKMapRect)mapRect
{
    CGPathRef path = self.path;
    if (!path) {
        return;
    }
    if (_shouldRasterize) {
        [self charon_drawRasterizedInContext:context zoomScale:zoomScale];
        return;
    }
    // The path is in the renderer's own points; MapKit's context for an overlay is already
    // transformed into that space, so the path is added as it stands.
    if (_fillColor) {
        [self applyFillPropertiesToContext:context atZoomScale:zoomScale];
        CGContextBeginPath(context);
        CGContextAddPath(context, path);
        CGContextFillPath(context);
    }
    if (_strokeColor) {
        [self applyStrokePropertiesToContext:context atZoomScale:zoomScale];
        [_strokeColor setStroke];
        CGContextBeginPath(context);
        CGContextAddPath(context, path);
        CGContextStrokePath(context);
    }
}

@end
