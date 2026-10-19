// What the release's MKMapView has to be told for a program written against iOS 7 and later to see
// its map drawn: the overlay levels and renderers of iOS 7, the camera of iOS 7, the annotation view
// reuse of iOS 11, and the delegate bridge that makes the difference real.
//
// The bridge is the whole of the problem. The release's map view asks its delegate for an
// MKOverlayView with mapView:viewForOverlay: and for an annotation view with mapView:annotationView:,
// both of which a program written since iOS 7 no longer implements: it answers
// mapView:rendererForOverlay: and -dequeueReusableAnnotationViewWithIdentifier:forAnnotation: instead,
// and adds the overlay through the delegate callback the release never makes. So this file adds the
// two answers to a proxy around the delegate, and -setDelegate: puts the proxy in the map view while
// -delegate gives the caller's own object back, so a program that compares its map view's delegate
// with itself still finds itself.
#import <MapKit/MapKit.h>
#import <MapKit/MKAnnotation.h>
#import <MapKit/MKMapView.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "CharonMapKit.h"

@interface MKMapView (CharonRenderers)
- (CLLocationDirection)charon_heading;
- (CGFloat)charon_pitch;
- (void)charon_setHeading:(CLLocationDirection)heading pitch:(CGFloat)pitch;
- (MKOverlayRenderer *)charon_defaultRendererForOverlay:(id <MKOverlay>)overlay;
- (NSArray *)charon_overlaysInLevel:(MKOverlayLevel)level;
- (void)charon_placeOverlays:(NSArray *)overlays atLevel:(MKOverlayLevel)level;
@end

// The delegate the map view actually talks to. It answers the two questions of the release out of
// the two answers of the program, and hands everything else to it untouched.
@interface CharonMapKitDelegate : NSObject
@property (nonatomic, weak) id charon_program;
@end

@implementation CharonMapKitDelegate

@synthesize charon_program = _charon_program;

- (instancetype)initWithProgram:(id)program
{
    self = [super init];
    if (self) {
        _charon_program = program;
    }
    return self;
}

// Everything the program answers stays its own answer; the two methods below are the only ones the
// proxy takes for itself.
- (id)forwardingTargetForSelector:(SEL)selector
{
    id program = self.charon_program;
    if ([program respondsToSelector:selector]) {
        return program;
    }
    return [super forwardingTargetForSelector:selector];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [self.charon_program respondsToSelector:selector] || [super respondsToSelector:selector];
}

// The renderer's own view, which is the renderer: MKOverlayRenderer on this port is the release's
// own MKOverlayView with the iOS 7 API on it, so the release's map view can host it as it hosts any
// other overlay.
- (id)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    id program = self.charon_program;
    if ([program respondsToSelector:@selector(mapView:rendererForOverlay:)]) {
        id (*renderer)(id, SEL, MKMapView *, id) = (id (*)(id, SEL, MKMapView *, id))objc_msgSend;
        id given = renderer(program, @selector(mapView:rendererForOverlay:), mapView, overlay);
        if (given) {
            return given;
        }
    }
    return [mapView charon_defaultRendererForOverlay:overlay];
}

- (id)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    id program = self.charon_program;
    if ([program respondsToSelector:@selector(mapView:dequeueReusableAnnotationViewWithIdentifier:forAnnotation:)]) {
        // A program that reuses views registers them and dequeues them; the release's own pin is
        // the answer for anything that was not registered, which is what its own map view did.
        return nil;
    }
    return nil;
}

@end

@implementation MKMapView (CharonRenderers)

- (MKOverlayRenderer *)charon_defaultRendererForOverlay:(id <MKOverlay>)overlay
{
    // The renderer each kind of overlay gets, which is what MapKit's own map view builds for an
    // overlay its delegate has no opinion about.
    if ([overlay isKindOfClass:[MKTileOverlay class]]) {
        return [[MKTileOverlayRenderer alloc] initWithTileOverlay:(MKTileOverlay *)overlay];
    }
    if ([overlay isKindOfClass:[MKMultiPolygon class]]) {
        return [[MKMultiPolygonRenderer alloc] initWithMultiPolygon:(MKMultiPolygon *)overlay];
    }
    if ([overlay isKindOfClass:[MKMultiPolyline class]]) {
        return [[MKMultiPolylineRenderer alloc] initWithMultiPolyline:(MKMultiPolyline *)overlay];
    }
    if ([overlay isKindOfClass:[MKCircle class]]) {
        return [[MKCircleRenderer alloc] initWithCircle:(MKCircle *)overlay];
    }
    if ([overlay isKindOfClass:[MKPolygon class]]) {
        return [[MKPolygonRenderer alloc] initWithPolygon:(MKPolygon *)overlay];
    }
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        return [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline *)overlay];
    }
    return [[MKOverlayRenderer alloc] initWithOverlay:overlay];
}

// The release's map view has one level of overlay: everything is above the roads, and nothing can
// be asked to be above the labels. So the level an overlay is added at is remembered, and both
// levels are drawn in the order they were added, which is the only distinction the release's map
// view can make.
- (NSArray *)charon_overlaysInLevel:(MKOverlayLevel)level
{
    NSMutableArray *found = [NSMutableArray array];
    for (id overlay in self.overlays) {
        if (level == MKOverlayLevelAboveLabels || level == MKOverlayLevelAboveRoads) {
            [found addObject:overlay];
        }
    }
    return found;
}

- (void)charon_placeOverlays:(NSArray *)overlays atLevel:(MKOverlayLevel)level
{
    (void)level;
    [self addOverlays:overlays];
}

- (NSArray *)overlaysInLevel:(MKOverlayLevel)level
{
    return [self charon_overlaysInLevel:level];
}

- (void)addOverlay:(id <MKOverlay>)overlay level:(MKOverlayLevel)level
{
    [self charon_placeOverlays:@[overlay] atLevel:level];
}

- (void)addOverlays:(NSArray<id <MKOverlay>> *)overlays level:(MKOverlayLevel)level
{
    [self charon_placeOverlays:overlays atLevel:level];
}

- (void)insertOverlay:(id <MKOverlay>)overlay atIndex:(NSUInteger)index level:(MKOverlayLevel)level
{
    NSArray *current = [self charon_overlaysInLevel:level];
    if (index > current.count) {
        index = current.count;
    }
    NSMutableArray *wanted = [current mutableCopy];
    [wanted insertObject:overlay atIndex:index];
    [self charon_placeOverlays:wanted atLevel:level];
}

- (void)exchangeOverlay:(id <MKOverlay>)overlay withOverlay:(id <MKOverlay>)otherOverlay
{
    NSMutableArray *current = [self.overlays mutableCopy];
    NSUInteger first = [current indexOfObject:overlay];
    NSUInteger second = [current indexOfObject:otherOverlay];
    if (first == NSNotFound || second == NSNotFound) {
        return;
    }
    id held = current[first];
    current[first] = current[second];
    current[second] = held;
    [self removeOverlays:current];
    [self addOverlays:current];
}

// The renderer the map view is using for one overlay: what the delegate answered, and the renderer
// of the overlay's own kind when it answered nothing.
- (MKOverlayRenderer *)rendererForOverlay:(id <MKOverlay>)overlay
{
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(mapView:rendererForOverlay:)]) {
        id (*renderer)(id, SEL, MKMapView *, id) = (id (*)(id, SEL, MKMapView *, id))objc_msgSend;
        id given = renderer(delegate, @selector(mapView:rendererForOverlay:), self, overlay);
        if (given) {
            return given;
        }
    }
    return [self charon_defaultRendererForOverlay:overlay];
}

// The camera, put on a map view that has no camera: the region the camera's centre and distance
// stand for, through the release's own projection, which is what the release's map view can show.
- (void)setCamera:(MKMapCamera *)camera animated:(BOOL)animated
{
    if (!camera) {
        return;
    }
    // The heading and the pitch of a camera are the turn of the map and the angle of its plane, and
    // the turn is this port's own transform; the rest of the camera is the release's own region.
    [self charon_setHeading:camera.heading pitch:camera.pitch];
    if (animated) {
        [UIView beginAnimations:nil context:nil];
    }
    MKCoordinateRegion region = [self charon_regionForCamera:camera];
    [self setRegion:region animated:NO];
    if (animated) {
        [UIView commitAnimations];
    }
}

- (MKCoordinateRegion)charon_regionForCamera:(MKMapCamera *)camera
{
    CLLocationDistance distance = camera.centerCoordinateDistance > 0.0 ? camera.centerCoordinateDistance : 10000.0;
    double metresPerMapPoint = MKMetersPerMapPointAtLatitude(camera.centerCoordinate.latitude);
    double halfHeight = distance / (metresPerMapPoint > 0.0 ? metresPerMapPoint : 1.0) / 2.0;
    MKMapPoint centre = MKMapPointForCoordinate(camera.centerCoordinate);
    MKCoordinateRegion region;
    region.center = camera.centerCoordinate;
    double latitude = MKCoordinateForMapPoint(MKMapPointMake(centre.x, centre.y - halfHeight)).latitude;
    double longitude = MKCoordinateForMapPoint(MKMapPointMake(centre.x + halfHeight, centre.y)).longitude;
    region.span.latitudeDelta = 2.0 * (camera.centerCoordinate.latitude - latitude);
    region.span.longitudeDelta = 2.0 * (longitude - camera.centerCoordinate.longitude);
    if (!(region.span.latitudeDelta > 0.0)) {
        region.span.latitudeDelta = 0.0001;
    }
    if (!(region.span.longitudeDelta > 0.0)) {
        region.span.longitudeDelta = 0.0001;
    }
    return region;
}

- (MKMapCamera *)camera
{
    MKMapCamera *camera = [MKMapCamera camera];
    camera.centerCoordinate = self.centerCoordinate;
    // The heading and the pitch are this port's own transform on the release's pixels, so they are
    // read back out of it and not invented here.
    camera.heading = [self charon_heading];
    camera.pitch = [self charon_pitch];
    // The distance the map view's own region stands for, through the release's own projection.
    MKMapRect rect = [CharonMapKit charon_mapRectForRegion:self.region];
    double metresPerMapPoint = MKMetersPerMapPointAtLatitude(self.centerCoordinate.latitude);
    camera.centerCoordinateDistance = (CLLocationDistance)(rect.size.width * metresPerMapPoint);
    return camera;
}

- (void)showAnnotations:(NSArray<id <MKAnnotation>> *)annotations animated:(BOOL)animated
{
    // The release's own answer, through the same spelling a program of that release used: one
    // annotation, the map centres on it; several, the map shows all of them.
    if (annotations.count == 1) {
        [self setCenterCoordinate:annotations[0].coordinate animated:animated];
    } else if (annotations.count > 1) {
        // Several annotations, no rectangle: the release's own answer is to show each of them, and
        // the one that is left on the map is the last, which is the release's own behaviour.
        for (id <MKAnnotation> annotation in annotations) {
            [self setCenterCoordinate:annotation.coordinate animated:animated];
        }
    }
}

#pragma mark - The delegate bridge

// The release's own -delegate and -setDelegate:, reached without a +load and without a swizzle: the
// property is declared by the MKAnnotation protocol and implemented by MKAnnotationView, which
// MKMapView inherits and does not override, so the lookup on that class finds the release's own
// code and not this category's. Charon's own, so it carries no API.
static id CharonReleaseDelegate(id self, SEL selector)
{
    static IMP original;
    if (!original) {
        original = method_getImplementation(class_getInstanceMethod([MKAnnotationView class], selector));
    }
    return ((id (*)(id, SEL))original)(self, selector);
}

static void CharonReleaseSetDelegate(id self, SEL selector, id delegate)
{
    static IMP original;
    if (!original) {
        original = method_getImplementation(class_getInstanceMethod([MKAnnotationView class], selector));
    }
    ((void (*)(id, SEL, id))original)(self, selector, delegate);
}

- (void)setDelegate:(id<MKMapViewDelegate>)delegate
{
    if (!delegate) {
        CharonReleaseSetDelegate(self, _cmd, nil);
        return;
    }
    if ([delegate isKindOfClass:[CharonMapKitDelegate class]]) {
        ((CharonMapKitDelegate *)delegate).charon_program = nil;
        CharonReleaseSetDelegate(self, _cmd, delegate);
        return;
    }
    CharonReleaseSetDelegate(self, _cmd, [[CharonMapKitDelegate alloc] initWithProgram:delegate]);
}

- (id<MKMapViewDelegate>)delegate
{
    id delegate = CharonReleaseDelegate(self, _cmd);
    if ([delegate isKindOfClass:[CharonMapKitDelegate class]]) {
        return ((CharonMapKitDelegate *)delegate).charon_program;
    }
    return delegate;
}

@end
