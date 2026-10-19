// The thirteen properties the release's own MKMapView has no answer for, each one doing what it can
// really do and saying so where it cannot.
//
// What the release's map view is, measured with apple.objc.inventory against the armv7 dyld shared
// cache of 6.1.3: 228 public instance methods, of which the map's own surface is a region
// (-setRegion:animated:, -setCenterCoordinate:animated:, -visibleMapRect, -mapRectThatFits:,
// -regionThatFits:, -convertCoordinate:toPointToView:), a map type (-mapType), the user location
// (-userTrackingMode, -setUserTrackingMode:animated:, -showsUserLocation), and the overlays. It has
// no showsTraffic, no showsBuildings, no showsPointsOfInterest, no showsCompass, no showsScale, no
// showsUserTrackingButton, no rotateEnabled, no pitchEnabled, no camera, no zoomScale, no
// pointOfInterestFilter, no preferredConfiguration, no cameraBoundary, no cameraZoomRange, no
// selectableMapFeatures and no pitchButtonVisibility -- its own -_rotationState, -canRotateForHeading
// and -setShouldRotateForHeading: are the private machinery that turns the map to follow the
// compass, which is not a public rotation and is not used here.
//
// So the map stays the release's: the heading and the pitch are a transform on the release's own
// pixels, driven by a real rotation gesture, with the annotation views counter-transformed so they
// stay upright. That is a projection of a plane, not the release's own three-dimensional camera,
// and the facts say so.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "CharonMapKit.h"

// The state one map view carries for this port. A Charon class of the port's own, held per map view
// through objc_setAssociatedObject, because a category cannot add an ivar to a release class and
// because the release's own map view must stay the release's.
@interface CharonMapViewState : NSObject
@property (nonatomic) BOOL rotateEnabled;
@property (nonatomic) BOOL pitchEnabled;
@property (nonatomic) CGFloat heading;
@property (nonatomic) CGFloat pitch;
@property (nonatomic) CGFloat eyeDistance;
@property (nonatomic) BOOL showsCompass;
@property (nonatomic) BOOL showsScale;
@property (nonatomic) BOOL showsUserTrackingButton;
@property (nonatomic) MKCompassButton *compass;
@property (nonatomic) MKScaleView *scale;
@property (nonatomic) MKUserTrackingButton *tracking;
@property (nonatomic) MKMapCameraBoundary *cameraBoundary;
@property (nonatomic) MKMapCameraZoomRange *cameraZoomRange;
@property (nonatomic) MKMapConfiguration *preferredConfiguration;
@property (nonatomic) BOOL selectableMapFeatures;
@property (nonatomic) NSInteger pitchButtonVisibility;
@property (nonatomic) NSInteger showsTraffic;
@property (nonatomic) NSInteger showsBuildings;
@property (nonatomic) NSInteger showsPointsOfInterest;
@property (nonatomic) MKPointOfInterestFilter *pointOfInterestFilter;
@end

@implementation CharonMapViewState
@synthesize rotateEnabled = _rotateEnabled;
@synthesize pitchEnabled = _pitchEnabled;
@synthesize heading = _heading;
@synthesize pitch = _pitch;
@synthesize eyeDistance = _eyeDistance;
@synthesize showsCompass = _showsCompass;
@synthesize showsScale = _showsScale;
@synthesize showsUserTrackingButton = _showsUserTrackingButton;
@synthesize compass = _compass;
@synthesize scale = _scale;
@synthesize tracking = _tracking;
@synthesize cameraBoundary = _cameraBoundary;
@synthesize cameraZoomRange = _cameraZoomRange;
@synthesize preferredConfiguration = _preferredConfiguration;
@synthesize selectableMapFeatures = _selectableMapFeatures;
@synthesize pitchButtonVisibility = _pitchButtonVisibility;
@synthesize showsTraffic = _showsTraffic;
@synthesize showsBuildings = _showsBuildings;
@synthesize showsPointsOfInterest = _showsPointsOfInterest;
@synthesize pointOfInterestFilter = _pointOfInterestFilter;

// The sign the release's own map has: a heading of zero is north up, and a positive heading turns
// the content anticlockwise on screen, so the screen's rotation is the heading negated.
- (CGFloat)charon_contentRotation
{
    return -_heading * (CGFloat)M_PI / 180.0;
}

- (CGFloat)charon_contentPitch
{
    return -_pitch * (CGFloat)M_PI / 180.0;
}
@end

@interface MKMapView (CharonCamera)
- (CharonMapViewState *)charon_state;
- (void)charon_startFollowingBounds;
- (void)charon_applyTransform;
- (void)charon_updateControls;
- (MKCoordinateRegion)charon_clampRegion:(MKCoordinateRegion)region;
- (void)charon_applyCameraAnimated:(BOOL)animated;
- (CGFloat)charon_metresAcross;
- (void)charon_inert:(NSString *)api why:(NSString *)why;
- (void)charon_installGesture;
- (void)charon_setHeading:(CLLocationDirection)heading pitch:(CGFloat)pitch;
@end

@implementation MKMapView (CharonCamera)

// The display link that follows the release's own layout, held beside the map view because a
// category cannot have an ivar. Charon's own, so it carries no API.
- (CADisplayLink *)charon_link
{
    return objc_getAssociatedObject(self, (const void *)"charonMapLink");
}

- (void)charon_setLink:(CADisplayLink *)link
{
    objc_setAssociatedObject(self, (const void *)"charonMapLink", link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CharonMapViewState *)charon_state
{
    static const void *key = &key;
    CharonMapViewState *state = objc_getAssociatedObject(self, key);
    if (!state) {
        state = [[CharonMapViewState alloc] init];
        objc_setAssociatedObject(self, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

// The transform, and the annotation views put back the way they were. The rotation is about the
// middle of the map view; the perspective is the projection of a plane at the eye distance, and the
// pitch is how far that plane is turned from flat. The release's annotation views are asked for
// through -viewForAnnotation:, which is the release's own public way of naming them, and each is
// given the inverse so it stays upright on a rotated map.
- (void)charon_applyTransform
{
    CharonMapViewState *state = [self charon_state];
    CGFloat rotation = state.rotateEnabled ? [state charon_contentRotation] : 0.0;
    CGFloat pitch = state.pitchEnabled ? [state charon_contentPitch] : 0.0;
    CGSize size = self.bounds.size;
    CGFloat distance = state.eyeDistance > 0.0 ? state.eyeDistance : 1000.0;
    CALayer *layer = self.layer;
    if (rotation == 0.0 && pitch == 0.0) {
        layer.transform = CATransform3DIdentity;
    } else {
        CATransform3D plane = CATransform3DMakeTranslation(size.width / 2.0, size.height / 2.0, 0.0);
        plane = CATransform3DRotate(plane, rotation, 0.0, 0.0, 1.0);
        plane = CATransform3DRotate(plane, pitch, 1.0, 0.0, 0.0);
        plane = CATransform3DTranslate(plane, -size.width / 2.0, -size.height / 2.0, 0.0);
        plane.m34 = -1.0 / distance;
        layer.transform = plane;
    }
    // A pin is a flat thing standing on the map, so what puts it upright is the inverse of the
    // map's own turn about the vertical, and nothing of the perspective.
    CATransform3D upright = CATransform3DInvert(CATransform3DMakeRotation(rotation, 0.0, 0.0, 1.0));
    for (id annotation in self.annotations) {
        MKAnnotationView *view = [self viewForAnnotation:annotation];
        if (view && [view isKindOfClass:[MKAnnotationView class]]) {
            view.layer.transform = upright;
        }
    }
    [(MKCompassButton *)state.compass setCompassHeading:state.heading];
    // The three controls' own frames, which the release's own layout does not know about and which
    // would otherwise stay where the map view used to be after a bounds change.
    [self charon_updateControls];
}

// The release's own -layoutSubviews is NOT replaced here, and this is deliberate and measured.
// Measured with apple.objc.inventory on the armv7 cache of 6.1.3: MKMapView has -layoutSubviews in
// its OWN method list, so a category's method for that selector would never be installed -- the
// runtime sets "ignore" when a class's implementation of a selector differs from its superclass's,
// and attach.c's charon_collect skips the same selector for the same reason -- and if some release
// lacked it, the lazy original-IMP lookup below would find the category's own and recurse until the
// stack ran out.
//
// So the transform is re-applied from the port's own entry points instead: the camera and heading
// setters, the rotation gesture, the three shows... setters through charon_updateControls, and a
// CADisplayLink while the map is rotated, which is where a bounds change shows up anyway. The
// release's own layout repositions the annotation views after any bounds change, so they are the
// thing to re-stand, and this is where that happens.
- (void)charon_startFollowingBounds
{
    if ([self charon_link]) {
        return;
    }
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(charon_followBounds:)];
    [self charon_setLink:link];
    [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)charon_followBounds:(CADisplayLink *)link
{
    // Only while there is something to stand back up: a map that is not rotated has no transform
    // to undo, and a display link that runs for nothing is a battery cost.
    CharonMapViewState *state = [self charon_state];
    if (state.rotateEnabled || state.pitchEnabled) {
        [self charon_applyTransform];
        [self charon_updateControls];
    }
}

#pragma mark - The rotation gesture

- (void)charon_installGesture
{
    UIRotationGestureRecognizer *gesture = objc_getAssociatedObject(self, (const void *)"charonRotationGesture");
    if (gesture) {
        return;
    }
    gesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(charon_rotate:)];
    gesture.delegate = (id<UIGestureRecognizerDelegate>)self;
    [self addGestureRecognizer:gesture];
    objc_setAssociatedObject(self, (const void *)"charonRotationGesture", gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)charon_rotate:(UIRotationGestureRecognizer *)gesture
{
    CharonMapViewState *state = [self charon_state];
    if (gesture.state == UIGestureRecognizerStateChanged) {
        // A clockwise turn of the fingers is a clockwise turn of the map, which is a heading that
        // counts down: north is up when the heading is zero.
        state.heading = (CGFloat)fmod((double)state.heading - (double)gesture.rotation * 180.0 / M_PI + 360.0, 360.0);
        gesture.rotation = 0.0;
        [self charon_applyTransform];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture
{
    if ([gesture isKindOfClass:[UIRotationGestureRecognizer class]]) {
        return [self charon_state].rotateEnabled;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    // Alongside the release's own pan and pinch, so rotating does not stop the map being panned.
    return [gesture isKindOfClass:[UIRotationGestureRecognizer class]];
}

#pragma mark - The properties

- (BOOL)rotateEnabled
{
    return [self charon_state].rotateEnabled;
}

- (void)setRotateEnabled:(BOOL)rotateEnabled
{
    [self charon_state].rotateEnabled = rotateEnabled;
    if (rotateEnabled) {
        [self charon_installGesture];
    }
    [self charon_applyTransform];
}

- (BOOL)pitchEnabled
{
    return [self charon_state].pitchEnabled;
}

- (void)setPitchEnabled:(BOOL)pitchEnabled
{
    CharonMapViewState *state = [self charon_state];
    state.pitchEnabled = pitchEnabled;
    if (pitchEnabled && state.eyeDistance <= 0.0) {
        // The eye distance a camera keeps with its distance, so a caller that only turns pitch on
        // gets the perspective a camera of that distance would have.
        state.eyeDistance = MAX(400.0, [self charon_metresAcross]);
    }
    if (pitchEnabled) {
        [self charon_startFollowingBounds];
    }
    [self charon_applyTransform];
}

- (CLLocationDirection)charon_heading
{
    return (CLLocationDirection)[self charon_state].heading;
}

- (CGFloat)charon_pitch
{
    return [self charon_state].pitch;
}

// The metres the map view's own visible rect is across, through the release's own metres per map
// point at the map's centre. Charon's own, so it carries no API.
- (void)charon_setHeading:(CLLocationDirection)heading pitch:(CGFloat)pitch
{
    CharonMapViewState *state = [self charon_state];
    state.heading = (CGFloat)fmod((double)heading, 360.0);
    state.pitch = MAX(0.0, MIN(90.0, (CGFloat)pitch));
    if (state.pitch > 0.0) {
        state.pitchEnabled = YES;
        if (state.eyeDistance <= 0.0) {
            state.eyeDistance = MAX(400.0, [self charon_metresAcross]);
        }
        [self charon_startFollowingBounds];
    }
    [self charon_applyTransform];
}

- (CGFloat)charon_metresAcross
{
    MKMapRect visible = self.visibleMapRect;
    if (visible.size.width <= 0.0) {
        return 2000.0;
    }
    return (CGFloat)(visible.size.width * MKMetersPerMapPointAtLatitude(self.centerCoordinate.latitude));
}

- (BOOL)showsCompass
{
    return [self charon_state].showsCompass;
}

- (void)setShowsCompass:(BOOL)showsCompass
{
    CharonMapViewState *state = [self charon_state];
    state.showsCompass = showsCompass;
    [self charon_updateControls];
}

- (BOOL)showsScale
{
    return [self charon_state].showsScale;
}

- (void)setShowsScale:(BOOL)showsScale
{
    CharonMapViewState *state = [self charon_state];
    state.showsScale = showsScale;
    [self charon_updateControls];
}

- (BOOL)showsUserTrackingButton
{
    return [self charon_state].showsUserTrackingButton;
}

- (void)setShowsUserTrackingButton:(BOOL)showsUserTrackingButton
{
    CharonMapViewState *state = [self charon_state];
    state.showsUserTrackingButton = showsUserTrackingButton;
    [self charon_updateControls];
}

- (MKFeatureVisibility)pitchButtonVisibility
{
    return (MKFeatureVisibility)[self charon_state].pitchButtonVisibility;
}

- (void)setPitchButtonVisibility:(MKFeatureVisibility)pitchButtonVisibility
{
    [self charon_state].pitchButtonVisibility = pitchButtonVisibility;
    [self charon_inert:@"MKMapView.pitchButtonVisibility"
                  why:@"the release's map view has no pitch button: its own public surface (228 methods, measured) is a region, a map type and the user location"];
}

- (BOOL)selectableMapFeatures
{
    return [self charon_state].selectableMapFeatures;
}

- (void)setSelectableMapFeatures:(BOOL)selectableMapFeatures
{
    [self charon_state].selectableMapFeatures = selectableMapFeatures;
    [self charon_inert:@"MKMapView.selectableMapFeatures"
                  why:@"the release's map view has no selectable features at all: it has no selection of its own, and the features a selection would choose between arrive with a map the release does not have"];
}

- (BOOL)showsTraffic
{
    return [self charon_state].showsTraffic != 0;
}

- (void)setShowsTraffic:(BOOL)showsTraffic
{
    [self charon_state].showsTraffic = showsTraffic ? 1 : 0;
    [self charon_inert:@"MKMapView.showsTraffic"
                  why:@"the release's map draws one fixed tile style and has no traffic layer to draw or not: -showsTraffic is not in its 228 public methods (measured) and its own trafficEnabled spelling belongs to another class"];
}

- (BOOL)showsBuildings
{
    return [self charon_state].showsBuildings != 0;
}

- (void)setShowsBuildings:(BOOL)showsBuildings
{
    [self charon_state].showsBuildings = showsBuildings ? 1 : 0;
    [self charon_inert:@"MKMapView.showsBuildings"
                  why:@"the release's map draws its buildings inside its own vector tiles, and there is no way to ask it for a style without them: the tile style is the release's own and this port has no way to vary it"];
}

- (BOOL)showsPointsOfInterest
{
    return [self charon_state].showsPointsOfInterest != 0;
}

- (void)setShowsPointsOfInterest:(BOOL)showsPointsOfInterest
{
    [self charon_state].showsPointsOfInterest = showsPointsOfInterest ? 1 : 0;
    [self charon_inert:@"MKMapView.showsPointsOfInterest"
                  why:@"the release's map draws its points of interest inside its own vector tiles, and there is no way to ask it for a style without them"];
}

- (MKPointOfInterestFilter *)pointOfInterestFilter
{
    return [self charon_state].pointOfInterestFilter;
}

- (void)setPointOfInterestFilter:(MKPointOfInterestFilter *)filter
{
    [self charon_state].pointOfInterestFilter = filter;
    [self charon_inert:@"MKMapView.pointOfInterestFilter"
                  why:@"the release's map draws its points of interest from its own tiles and takes no filter, so there is nothing for a filter to act on"];
}

// A property that is stored and that the release's map cannot act on says so once, the first time it
// is used, and never again: the README's answer for a visual effect the release cannot draw. Charon's
// own, so it carries no API.
- (void)charon_inert:(NSString *)api why:(NSString *)why
{
    static NSMutableSet *told;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        told = [[NSMutableSet alloc] init];
    });
    @synchronized(told) {
        if ([told containsObject:api]) {
            return;
        }
        [told addObject:api];
        NSLog(@"MKMapBackports: %s is stored and read back, and %@", [api UTF8String], why);
    }
}

// The three controls, put on the map view and taken off it again.
- (void)charon_updateControls
{
    CharonMapViewState *state = [self charon_state];
    CGSize size = self.bounds.size;
    CGFloat margin = 8.0;
    if (state.showsCompass) {
        if (!state.compass) {
            state.compass = [MKCompassButton compassButtonWithMapView:self];
        }
        if (state.compass.superview != self) {
            [self addSubview:state.compass];
        }
        state.compass.frame = CGRectMake(CGRectGetWidth(self.bounds) - 52.0 - margin, margin, 44.0, 44.0);
        state.compass.hidden = NO;
        [(MKCompassButton *)state.compass setCompassHeading:state.heading];
    } else if (state.compass) {
        [state.compass removeFromSuperview];
    }
    if (state.showsUserTrackingButton) {
        if (!state.tracking) {
            state.tracking = [MKUserTrackingButton userTrackingButtonWithMapView:self];
        }
        if (state.tracking.superview != self) {
            [self addSubview:state.tracking];
        }
        state.tracking.frame = CGRectMake(CGRectGetMaxX(self.bounds) - 44.0 - margin, CGRectGetMaxY(self.bounds) - 44.0 - margin, 44.0, 44.0);
        state.tracking.hidden = NO;
    } else if (state.tracking) {
        [state.tracking removeFromSuperview];
    }
    if (state.showsScale) {
        if (!state.scale) {
            state.scale = [MKScaleView scaleViewWithMapView:self];
        }
        if (state.scale.superview != self) {
            [self addSubview:state.scale];
        }
        state.scale.frame = CGRectMake(margin, CGRectGetMaxY(self.bounds) - 30.0, 110.0, 24.0);
        state.scale.hidden = NO;
        [state.scale setNeedsLayout];
    } else if (state.scale) {
        [state.scale removeFromSuperview];
    }
    (void)size;
}

#pragma mark - The camera's boundary and zoom range

- (MKMapCameraBoundary *)cameraBoundary
{
    return [self charon_state].cameraBoundary;
}

// A boundary with no region is the whole world, which is what nil means and what a boundary of the
// whole world does, so an unbounded map is not a special case here.
- (MKCoordinateRegion)charon_boundedRegion
{
    MKMapCameraBoundary *boundary = [self charon_state].cameraBoundary;
    MKMapRect rect = boundary ? boundary.mapRect : MKMapRectWorld;
    return MKCoordinateRegionForMapRect(rect);
}

- (void)setCameraBoundary:(MKMapCameraBoundary *)cameraBoundary
{
    [self charon_state].cameraBoundary = cameraBoundary;
}

- (void)setCameraBoundary:(MKMapCameraBoundary *)cameraBoundary animated:(BOOL)animated
{
    [self setCameraBoundary:cameraBoundary];
    [self charon_applyCameraAnimated:animated];
}

- (MKMapCameraZoomRange *)cameraZoomRange
{
    return [self charon_state].cameraZoomRange;
}

- (void)setCameraZoomRange:(MKMapCameraZoomRange *)cameraZoomRange
{
    [self charon_state].cameraZoomRange = cameraZoomRange;
}

- (void)setCameraZoomRange:(MKMapCameraZoomRange *)cameraZoomRange animated:(BOOL)animated
{
    [self setCameraZoomRange:cameraZoomRange];
    [self charon_applyCameraAnimated:animated];
}

// A region inside the boundary and inside the zoom range, which is what the two are: the boundary
// is an area the camera may not leave, and the zoom range is how close and how far the two ends of
// the camera's distance may be. Charon's own, so it carries no API.
- (MKCoordinateRegion)charon_clampRegion:(MKCoordinateRegion)region
{
    MKCoordinateRegion bounded = [self charon_boundedRegion];
    double centreLat = MAX(CLLocationCoordinate2DIsValid(bounded.center) ? bounded.center.latitude : -90.0,
                           MIN(90.0, region.center.latitude));
    double centreLon = region.center.longitude;
    double latitudeDelta = region.span.latitudeDelta;
    double longitudeDelta = region.span.longitudeDelta;
    if (CLLocationCoordinate2DIsValid(bounded.center)) {
        double halfLat = bounded.span.latitudeDelta / 2.0;
        if (halfLat > 0.0) {
            centreLat = MAX(bounded.center.latitude - halfLat, MIN(bounded.center.latitude + halfLat, centreLat));
            latitudeDelta = MIN(latitudeDelta, bounded.span.latitudeDelta);
        }
        double halfLon = bounded.span.longitudeDelta / 2.0;
        if (halfLon > 0.0) {
            centreLon = MAX(bounded.center.longitude - halfLon, MIN(bounded.center.longitude + halfLon, centreLon));
            longitudeDelta = MIN(longitudeDelta, bounded.span.longitudeDelta);
        }
    }
    MKMapCameraZoomRange *zoom = [self charon_state].cameraZoomRange;
    if (zoom) {
        // The camera's distance is how far the map is zoomed out, and the map's own metres across
        // is that distance, through the release's own metres per map point.
        double metresAcross = (double)[self charon_metresAcross];
        double lowest = zoom.minCenterCoordinateDistance > 0.0 ? zoom.minCenterCoordinateDistance : 0.0;
        double highest = zoom.maxCenterCoordinateDistance > 0.0 ? zoom.maxCenterCoordinateDistance : 0.0;
        if (metresAcross > 0.0) {
            if (lowest > 0.0 && metresAcross < lowest) {
                latitudeDelta = MIN(180.0, latitudeDelta * metresAcross / lowest);
                longitudeDelta = MIN(360.0, longitudeDelta * metresAcross / lowest);
            } else if (highest > 0.0 && metresAcross > highest) {
                latitudeDelta = MIN(180.0, latitudeDelta * highest / metresAcross);
                longitudeDelta = MIN(360.0, longitudeDelta * highest / metresAcross);
            }
        }
    }
    if (!(latitudeDelta > 0.0)) {
        latitudeDelta = 0.0001;
    }
    if (!(longitudeDelta > 0.0)) {
        longitudeDelta = 0.0001;
    }
    region.center = CLLocationCoordinate2DMake(centreLat, centreLon);
    region.span = MKCoordinateSpanMake(MIN(latitudeDelta, 180.0), MIN(longitudeDelta, 360.0));
    return region;
}

// The map put back where this port's camera says, inside the boundary and the zoom range.
- (void)charon_applyCameraAnimated:(BOOL)animated
{
    MKMapCamera *camera = self.camera;
    if (!camera) {
        return;
    }
    // A camera is a centre and a distance; the region that says the same thing is that centre and
    // the span the distance stands for, through the release's own projection.
    MKMapPoint centre = MKMapPointForCoordinate(camera.centerCoordinate);
    double metresPerPoint = MKMetersPerMapPointAtLatitude(camera.centerCoordinate.latitude);
    double distance = camera.centerCoordinateDistance > 0.0 ? camera.centerCoordinateDistance : 1000.0;
    MKMapRect rect = MKMapRectMake(centre.x, centre.y, metresPerPoint > 0.0 ? distance / metresPerPoint : 0.0,
                                   metresPerPoint > 0.0 ? distance / metresPerPoint : 0.0);
    [self setRegion:[self charon_clampRegion:MKCoordinateRegionForMapRect(rect)] animated:animated];
}

#pragma mark - The configuration and the map type

- (MKMapConfiguration *)preferredConfiguration
{
    MKMapConfiguration *configuration = [self charon_state].preferredConfiguration;
    if (!configuration) {
        // What the release's own map type already is, said in the iOS 16 spelling: this is the same
        // map, and a program that reads the configuration back gets the map it is looking at.
        switch (self.mapType) {
            case MKMapTypeSatellite:
                configuration = [[MKImageryMapConfiguration alloc] init];
                break;
            case MKMapTypeHybrid:
                configuration = [[MKHybridMapConfiguration alloc] init];
                break;
            default:
                configuration = [[MKStandardMapConfiguration alloc] init];
                break;
        }
        [self charon_state].preferredConfiguration = configuration;
    }
    return configuration;
}

// The map type a configuration stands for, which is the part of a configuration the release's map
// can be told: the standard, the hybrid and the imagery map are the release's three map types, and
// the rest of a configuration has no counterpart in a map type and is stored and given back.
- (void)setPreferredConfiguration:(MKMapConfiguration *)preferredConfiguration
{
    [self charon_state].preferredConfiguration = preferredConfiguration;
    if ([preferredConfiguration isKindOfClass:[MKHybridMapConfiguration class]]) {
        self.mapType = MKMapTypeHybrid;
    } else if ([preferredConfiguration isKindOfClass:[MKImageryMapConfiguration class]]) {
        self.mapType = MKMapTypeSatellite;
    } else if ([preferredConfiguration isKindOfClass:[MKStandardMapConfiguration class]]) {
        self.mapType = MKMapTypeStandard;
    }
}

@end
