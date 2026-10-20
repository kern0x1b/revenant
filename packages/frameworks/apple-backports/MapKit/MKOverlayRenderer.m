#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "RevenantMapKitUI.h"

@implementation MKOverlayRenderer {
    CGBlendMode _blendMode;
    double _revenantMapPointsPerPoint;
    MKMapPoint _revenantMapOrigin;
    CGPoint _revenantViewOrigin;
}

@synthesize overlay = _overlay;
@synthesize blendMode = _blendMode;

- (instancetype)initWithOverlay:(id <MKOverlay>)overlay
{
    id (*revenant_init)(id, SEL, id) = (id (*)(id, SEL, id))objc_msgSend;
    self = revenant_init([[self class] alloc], @selector(initWithOverlay:), overlay);
    if (self) {
        _overlay = overlay;
        _blendMode = kCGBlendModeNormal;
        [(id<RevenantOverlayView>)self setBackgroundColor:[UIColor clearColor]];
        [(id<RevenantOverlayView>)self setOpaque:NO];
        [(id<RevenantOverlayView>)self setUserInteractionEnabled:NO];
        [(id<RevenantOverlayView>)self setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self revenant_recompute];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    id (*revenant_coder)(id, SEL, NSCoder *) = (id (*)(id, SEL, NSCoder *))objc_msgSend;
    self = revenant_coder([[self class] alloc], @selector(initWithCoder:), coder);
    if (self) {
        _blendMode = kCGBlendModeNormal;
        [self revenant_recompute];
    }
    return self;
}

- (void)revenant_recompute
{
    MKMapRect bounds = self.overlay ? self.overlay.boundingMapRect : MKMapRectWorld;
    CGRect view = [(id<RevenantOverlayView>)self bounds];
    _revenantMapOrigin = bounds.origin;
    _revenantViewOrigin = view.origin;
    if (view.size.width > 0.0 && bounds.size.width > 0.0) {
        _revenantMapPointsPerPoint = bounds.size.width / view.size.width;
    } else if (view.size.height > 0.0 && bounds.size.height > 0.0) {
        _revenantMapPointsPerPoint = bounds.size.height / view.size.height;
    } else {
        _revenantMapPointsPerPoint = 1.0;
    }
}

- (void)setFrame:(CGRect)frame
{
    [(id<RevenantOverlayView>)self setFrame:frame];
    [self revenant_recompute];
}

- (void)setBounds:(CGRect)bounds
{
    [(id<RevenantOverlayView>)self setBounds:bounds];
    [self revenant_recompute];
}

- (CGPoint)pointForMapPoint:(MKMapPoint)mapPoint
{
    [self revenant_recompute];
    double per = _revenantMapPointsPerPoint;
    return CGPointMake(_revenantViewOrigin.x + (mapPoint.x - _revenantMapOrigin.x) / per,
                       _revenantViewOrigin.y + (mapPoint.y - _revenantMapOrigin.y) / per);
}

- (MKMapPoint)mapPointForPoint:(CGPoint)point
{
    [self revenant_recompute];
    double per = _revenantMapPointsPerPoint;
    return MKMapPointMake(_revenantMapOrigin.x + (point.x - _revenantViewOrigin.x) * per,
                          _revenantMapOrigin.y + (point.y - _revenantViewOrigin.y) * per);
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

- (void)revenant_drawInContext:(CGContextRef)context zoomScale:(MKZoomScale)zoomScale mapRect:(MKMapRect)mapRect
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
    [self revenant_drawInContext:context zoomScale:zoomScale mapRect:wanted];
    CGContextRestoreGState(context);
}

- (void)setNeedsDisplay
{
    [(id<RevenantOverlayView>)self setNeedsDisplay];
    [self setNeedsDisplayInMapRect:self.overlay ? self.overlay.boundingMapRect : MKMapRectWorld];
}

- (MKZoomScale)revenant_zoomScale
{
    MKMapSize size = self.overlay ? self.overlay.boundingMapRect.size : MKMapSizeWorld;
    return [RevenantMapKit revenant_zoomScaleForMapSize:size];
}
- (void)setNeedsDisplayInMapRect:(MKMapRect)mapRect
{
    [self setNeedsDisplayInMapRect:mapRect zoomScale:[self revenant_zoomScale]];
}

- (void)setNeedsDisplayInMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale
{
    CGRect rect = [self rectForMapRect:mapRect];
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) {
        return;
    }
    [(id<RevenantOverlayView>)self setNeedsDisplayInRect:rect];
}

- (CGFloat)alpha
{
    return [(id<RevenantOverlayView>)self alpha];
}

- (void)setAlpha:(CGFloat)alpha
{
    [(id<RevenantOverlayView>)self setAlpha:alpha];
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
