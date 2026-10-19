#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "CharonMapKitUI.h"

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

- (void)charon_drawInContext:(CGContextRef)context zoomScale:(MKZoomScale)zoomScale mapRect:(MKMapRect)mapRect
{
}

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
    if (![UIScreen instancesRespondToSelector:@selector(scale)]) {
        return 1.0;
    }
    CGFloat (*scale)(id, SEL) = (CGFloat (*)(id, SEL))objc_msgSend;
    CGFloat value = scale([UIScreen mainScreen], @selector(scale));
    return value > 0.0 ? value : 1.0;
}

@end
