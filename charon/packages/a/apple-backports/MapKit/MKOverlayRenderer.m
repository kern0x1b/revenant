// MKOverlayRenderer: MapKit's iOS 7 answer to a question the release's own MKOverlayView answered
// differently.
//
// The release's MKMapView asks its delegate for an MKOverlayView, sizes it and drives it with
// canDrawMapRect:zoomScale: and drawMapRect:zoomScale:inContext:. A program written against iOS 7
// and later answers mapView:rendererForOverlay: with an MKOverlayRenderer, which the release's
// map view has never heard of and would leave undrawn. So MKOverlayRenderer here is a subclass of
// the release's own MKOverlayView: the same two drawing selectors over the same map-point
// arithmetic, the release's own view behind them, and the whole of the API the iOS 7 header
// declares on top. From 7.0 the release carries the class itself and this object is left out of
// every band that does, so the two never both answer a name.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "CharonMapKitUI.h"

// The transform between the renderer's own point space and the map's. Apple's renderer is handed
// the visible map rect and draws in the overlay's coordinates; on this release the renderer is a
// real view inside MKMapView, so the two spaces are tied by the overlay's bounding map rect and the
// view's bounds, which the map view sizes together. Reading the scale off the view rather than off
// the map view's zoom scale keeps the two consistent when the map moves: the view and the overlay
// are scaled by the same factor, and the view is the one that can be measured.
// The transform, in three private ivars rather than in a class extension: a property of the
// extension would have to be explicitly synthesized (the build compiles with
// -Werror=objc-missing-property-synthesis) and an accessor is an API name the registry check then
// wants an entry for. The class extension carries only the release's own readonly overlay, which
// the subclass has to answer itself.
// The transform, in three private ivars rather than in a class extension: a property of the
// extension would have to be explicitly synthesized (the build compiles with
// -Werror=objc-missing-property-synthesis) and an accessor is an API name the registry check then
// wants an entry for. The readwrite spelling of the overlay is in CharonMapKit.h, for every object
// that needs it.
@implementation MKOverlayRenderer {
    CGBlendMode _blendMode;
    double _charonMapPointsPerPoint;
    MKMapPoint _charonMapOrigin;
    CGPoint _charonViewOrigin;
}

@synthesize overlay = _overlay;
@synthesize blendMode = _blendMode;

- (instancetype)initWithOverlay:(id <MKOverlay>)overlay
{
    // The release's own MKOverlayView initialiser, on an object of this class: the 16.4 header says
    // MKOverlayRenderer's superclass is NSObject, which is the header's way of hiding that a
    // renderer is the release's own overlay view, and that initialiser is the one that sets it up.
    // Charon's own, so it carries no API.
    id (*charon_init)(id, SEL, id) = (id (*)(id, SEL, id))objc_msgSend;
    self = charon_init([[self class] alloc], @selector(initWithOverlay:), overlay);
    if (self) {
        _overlay = overlay;
        _blendMode = kCGBlendModeNormal;
        [(id<CharonOverlayView>)self setBackgroundColor:[UIColor clearColor]];
        [(id<CharonOverlayView>)self setOpaque:NO];
        [(id<CharonOverlayView>)self setUserInteractionEnabled:NO];
        [(id<CharonOverlayView>)self setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self charon_recompute];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    id (*charon_coder)(id, SEL, NSCoder *) = (id (*)(id, SEL, NSCoder *))objc_msgSend;
    self = charon_coder([[self class] alloc], @selector(initWithCoder:), coder);
    if (self) {
        _blendMode = kCGBlendModeNormal;
        [self charon_recompute];
    }
    return self;
}

// The scale from the overlay's bounding map rect to the view's own points. A view with no size
// yet has no scale to read, so one map point to one point until it is laid out; every call to
// pointForMapPoint: and mapPointForPoint: recomputes, so the transform is right as soon as the view
// has a size, and no stale scale is ever drawn with.
- (void)charon_recompute
{
    MKMapRect bounds = self.overlay ? self.overlay.boundingMapRect : MKMapRectWorld;
    CGRect view = [(id<CharonOverlayView>)self bounds];
    _charonMapOrigin = bounds.origin;
    _charonViewOrigin = view.origin;
    if (view.size.width > 0.0 && bounds.size.width > 0.0) {
        _charonMapPointsPerPoint = bounds.size.width / view.size.width;
    } else if (view.size.height > 0.0 && bounds.size.height > 0.0) {
        _charonMapPointsPerPoint = bounds.size.height / view.size.height;
    } else {
        _charonMapPointsPerPoint = 1.0;
    }
}

- (void)setFrame:(CGRect)frame
{
    [(id<CharonOverlayView>)self setFrame:frame];
    [self charon_recompute];
}

- (void)setBounds:(CGRect)bounds
{
    [(id<CharonOverlayView>)self setBounds:bounds];
    [self charon_recompute];
}

- (CGPoint)pointForMapPoint:(MKMapPoint)mapPoint
{
    [self charon_recompute];
    double per = _charonMapPointsPerPoint;
    return CGPointMake(_charonViewOrigin.x + (mapPoint.x - _charonMapOrigin.x) / per,
                       _charonViewOrigin.y + (mapPoint.y - _charonMapOrigin.y) / per);
}

- (MKMapPoint)mapPointForPoint:(CGPoint)point
{
    [self charon_recompute];
    double per = _charonMapPointsPerPoint;
    return MKMapPointMake(_charonMapOrigin.x + (point.x - _charonViewOrigin.x) * per,
                          _charonMapOrigin.y + (point.y - _charonViewOrigin.y) * per);
}

- (CGRect)rectForMapRect:(MKMapRect)mapRect
{
    CGPoint topLeft = [self pointForMapPoint:mapRect.origin];
    CGPoint bottomRight = [self pointForMapPoint:MKMapPointMake(MKMapRectGetMaxX(mapRect), MKMapRectGetMaxY(mapRect))];
    return CGRectMake(MIN(topLeft.x, bottomRight.x), MIN(topLeft.y, bottomRight.y),
                      fabs(bottomRight.x - topLeft.x), fabs(bottomRight.y - topLeft.y));
}

- (MKMapRect)mapRectForRect:(CGRect)rect
{
    MKMapPoint topLeft = [self mapPointForPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect))];
    MKMapPoint bottomRight = [self mapPointForPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect))];
    return MKMapRectMake(MIN(topLeft.x, bottomRight.x), MIN(topLeft.y, bottomRight.y),
                         fabs(bottomRight.x - topLeft.x), fabs(bottomRight.y - topLeft.y));
}

- (BOOL)canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale
{
    MKMapRect visible = self.overlay ? self.overlay.boundingMapRect : MKMapRectWorld;
    return !MKMapRectIsEmpty(MKMapRectIntersection(mapRect, visible));
}

// The drawing hook: the base renderer has no shape of its own, the path renderers above it fill
// and stroke one. Charon's own, so no API carries it (see CharonMapKit.h).
- (void)charon_drawInContext:(CGContextRef)context zoomScale:(MKZoomScale)zoomScale mapRect:(MKMapRect)mapRect
{
}

// The release's map view calls this with the part of the overlay it is about to draw.
- (void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
{
    MKMapRect visible = self.overlay ? self.overlay.boundingMapRect : MKMapRectWorld;
    MKMapRect wanted = MKMapRectIntersection(mapRect, visible);
    if (MKMapRectIsEmpty(wanted) || !context) {
        return;
    }
    CGContextSaveGState(context);
    CGContextSetAlpha(context, (CGFloat)self.alpha);
    if (_blendMode != kCGBlendModeNormal) {
        CGContextSetBlendMode(context, _blendMode);
    }
    [self charon_drawInContext:context zoomScale:zoomScale mapRect:wanted];
    CGContextRestoreGState(context);
}

- (void)setNeedsDisplay
{
    [(id<CharonOverlayView>)self setNeedsDisplay];
    [self setNeedsDisplayInMapRect:self.overlay ? self.overlay.boundingMapRect : MKMapRectWorld];
}

// The zoom scale the overlay is being drawn at, read back out of the overlay's own size: the
// release's map view hands the same number to every renderer, and this is where a renderer that
// has to answer without one (a stroke, a fill, a line width) gets it.
- (MKZoomScale)charon_zoomScale
{
    MKMapSize size = self.overlay ? self.overlay.boundingMapRect.size : MKMapSizeWorld;
    return [CharonMapKit charon_zoomScaleForMapSize:size];
}
- (void)setNeedsDisplayInMapRect:(MKMapRect)mapRect
{
    [self setNeedsDisplayInMapRect:mapRect zoomScale:[self charon_zoomScale]];
}

- (void)setNeedsDisplayInMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale
{
    CGRect rect = [self rectForMapRect:mapRect];
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) {
        return;
    }
    [(id<CharonOverlayView>)self setNeedsDisplayInRect:rect];
}

// The renderer's opacity, which is the view's own: a renderer is the release's own overlay view,
// so its alpha is that view's alpha and the pixels MapKit draws through it are drawn at that
// opacity. The header declares alpha of its own, and this is where it goes.
- (CGFloat)alpha
{
    return [(id<CharonOverlayView>)self alpha];
}

- (void)setAlpha:(CGFloat)alpha
{
    [(id<CharonOverlayView>)self setAlpha:alpha];
}

- (CGFloat)contentScaleFactor
{
    // The screen's own scale, where the release has one to ask: UIScreen.scale arrived in iOS 7.
    // A release without it has one point per pixel, which is what a device that predates the
    // Retina screens really is; the renderer then draws in the device's own points.
    if (![UIScreen instancesRespondToSelector:@selector(scale)]) {
        return 1.0;
    }
    CGFloat (*scale)(id, SEL) = (CGFloat (*)(id, SEL))objc_msgSend;
    CGFloat value = scale([UIScreen mainScreen], @selector(scale));
    return value > 0.0 ? value : 1.0;
}

@end
