#import <MapKit/MapKit.h>
#import <MapKit/MKMarkerAnnotationView.h>
#import <MapKit/MKClusterAnnotation.h>
#import <MapKit/MKMapView.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "RevenantMapKit.h"

@implementation MKMarkerAnnotationView {
    UIColor *_markerTintColor;
    UIColor *_glyphTintColor;
    NSString *_glyphText;
    UIImage *_glyphImage;
    UIImage *_selectedGlyphImage;
    MKFeatureVisibility _titleVisibility;
    MKFeatureVisibility _subtitleVisibility;
    BOOL _animatesWhenAdded;
}

@synthesize markerTintColor = _markerTintColor;
@synthesize glyphTintColor = _glyphTintColor;
@synthesize glyphText = _glyphText;
@synthesize glyphImage = _glyphImage;
@synthesize selectedGlyphImage = _selectedGlyphImage;
@synthesize titleVisibility = _titleVisibility;
@synthesize subtitleVisibility = _subtitleVisibility;
@synthesize animatesWhenAdded = _animatesWhenAdded;

- (instancetype)initWithAnnotation:(id <MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self) {
        _markerTintColor = [UIColor redColor];
        _glyphTintColor = [UIColor whiteColor];
        _titleVisibility = MKFeatureVisibilityAdaptive;
        _subtitleVisibility = MKFeatureVisibilityHidden;
        _animatesWhenAdded = YES;
    }
    return self;
}

- (void)setMarkerTintColor:(UIColor *)color
{
    _markerTintColor = color;
    [self setNeedsDisplay];
}

- (void)setGlyphText:(NSString *)text
{
    _glyphText = [text copy];
    [self setNeedsDisplay];
}

- (void)setGlyphImage:(UIImage *)image
{
    _glyphImage = image;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }
    CGRect box = CGRectInset(self.bounds, 2.0, 2.0);
    if (CGRectIsEmpty(box)) {
        return;
    }
    CGFloat circleSize = MIN(CGRectGetWidth(box), CGRectGetHeight(box) * 0.66);
    CGRect circle = CGRectMake(CGRectGetMidX(box) - circleSize / 2.0, CGRectGetMinY(box), circleSize, circleSize);
    [_markerTintColor setFill];
    UIBezierPath *pin = [UIBezierPath bezierPathWithOvalInRect:circle];
    [pin fill];
    CGFloat stalkWidth = circleSize / 5.0;
    UIBezierPath *stalk = [UIBezierPath bezierPath];
    [stalk moveToPoint:CGPointMake(CGRectGetMidX(circle) - stalkWidth / 2.0, CGRectGetMaxY(circle) - 1.0)];
    [stalk addLineToPoint:CGPointMake(CGRectGetMidX(circle) + stalkWidth / 2.0, CGRectGetMaxY(circle) - 1.0)];
    [stalk addLineToPoint:CGPointMake(CGRectGetMidX(circle), CGRectGetMaxY(box))];
    [stalk closePath];
    [stalk fill];
    CGRect glyphBox = CGRectInset(circle, circleSize / 6.0, circleSize / 6.0);
    if (_glyphImage) {
        [_glyphImage drawInRect:glyphBox];
        return;
    }
    if (_glyphText.length == 0) {
        return;
    }
    UIFont *font = [UIFont systemFontOfSize:MAX(8.0, circleSize / 3.0)];
    CGSize text = [_glyphText sizeWithFont:font];
    CGPoint at = CGPointMake(CGRectGetMidX(circle) - text.width / 2.0, CGRectGetMidY(circle) - text.height / 2.0);
    CGContextSaveGState(context);
    [[_glyphTintColor colorWithAlphaComponent:1.0] setFill];
    [_glyphText drawAtPoint:at withFont:font];
    CGContextRestoreGState(context);
}

@end

@implementation MKClusterAnnotation {
    NSArray<id <MKAnnotation>> *_memberAnnotations;
}

@synthesize memberAnnotations = _memberAnnotations;
@dynamic title, subtitle;

- (instancetype)initWithMemberAnnotations:(NSArray<id <MKAnnotation>> *)memberAnnotations
{
    self = [super init];
    if (self) {
        _memberAnnotations = [memberAnnotations copy] ?: @[];
    }
    return self;
}

- (NSString *)title
{
    return nil;
}

- (NSString *)subtitle
{
    return nil;
}

- (CLLocationCoordinate2D)coordinate
{
    NSUInteger count = 0;
    MKMapPoint sum = MKMapPointMake(0.0, 0.0);
    for (id <MKAnnotation> member in _memberAnnotations) {
        CLLocationCoordinate2D coordinate = member.coordinate;
        if (!CLLocationCoordinate2DIsValid(coordinate)) {
            continue;
        }
        MKMapPoint point = MKMapPointForCoordinate(coordinate);
        sum.x += point.x;
        sum.y += point.y;
        count++;
    }
    if (count == 0) {
        return kCLLocationCoordinate2DInvalid;
    }
    return MKCoordinateForMapPoint(MKMapPointMake(sum.x / (double)count, sum.y / (double)count));
}

@end

@implementation MKMapView (RevenantAnnotationViews)

- (void)registerClass:(Class)annotationViewClass forAnnotationViewWithReuseIdentifier:(NSString *)identifier
{
    NSMutableDictionary *registered = [[self revenant_registeredClasses] mutableCopy];
    registered[identifier] = annotationViewClass;
    [self revenant_setRegisteredClasses:registered];
}

- (NSMutableDictionary *)revenant_registeredClasses
{
    static NSMutableDictionary *registered;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        registered = [[NSMutableDictionary alloc] init];
    });
    return registered;
}


- (void)revenant_setRegisteredClasses:(NSDictionary *)classes
{
    NSMutableDictionary *registered = (NSMutableDictionary *)[self revenant_registeredClasses];
    [registered removeAllObjects];
    [registered addEntriesFromDictionary:classes ?: @{}];
}

- (MKAnnotationView *)dequeueReusableAnnotationViewWithIdentifier:(NSString *)identifier
                                                 forAnnotation:(id <MKAnnotation>)annotation
{
    if (identifier.length == 0 || !annotation) {
        return nil;
    }
    Class viewClass = [self revenant_registeredClasses][identifier];
    if (!viewClass) {
        if ([annotation isKindOfClass:[MKClusterAnnotation class]]) {
            viewClass = [MKMarkerAnnotationView class];
        } else {
            viewClass = [MKPinAnnotationView class];
        }
    }
    SEL initialiser = NSSelectorFromString(@"initWithAnnotation:reuseIdentifier:");
    if (![viewClass instancesRespondToSelector:initialiser]) {
        return nil;
    }
    id (*make)(id, SEL, id, id) = (id (*)(id, SEL, id, id))objc_msgSend;
    return make(viewClass, initialiser, annotation, identifier);
}

@end
