#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "RevenantMapKit.h"

@interface RevenantMapViewState : NSObject
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

@implementation RevenantMapViewState
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

- (CGFloat)revenant_contentRotation
{
    return -_heading * (CGFloat)M_PI / 180.0;
}

- (CGFloat)revenant_contentPitch
{
    return -_pitch * (CGFloat)M_PI / 180.0;
}
@end

@interface MKMapView (RevenantCamera)
- (RevenantMapViewState *)revenant_state;
- (void)revenant_startFollowingBounds;
- (void)revenant_applyTransform;
- (void)revenant_updateControls;
- (MKCoordinateRegion)revenant_clampRegion:(MKCoordinateRegion)region;
- (void)revenant_applyCameraAnimated:(BOOL)animated;
- (CGFloat)revenant_metresAcross;
- (void)revenant_inert:(NSString *)api why:(NSString *)why;
- (void)revenant_installGesture;
- (void)revenant_setHeading:(CLLocationDirection)heading pitch:(CGFloat)pitch;
@end

@implementation MKMapView (RevenantCamera)

- (CADisplayLink *)revenant_link
{
    return objc_getAssociatedObject(self, (const void *)"revenantMapLink");
}

- (void)revenant_setLink:(CADisplayLink *)link
{
    objc_setAssociatedObject(self, (const void *)"revenantMapLink", link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (RevenantMapViewState *)revenant_state
{
    static const void *key = &key;
    RevenantMapViewState *state = objc_getAssociatedObject(self, key);
    if (!state) {
        state = [[RevenantMapViewState alloc] init];
        objc_setAssociatedObject(self, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

- (void)revenant_applyTransform
{
    RevenantMapViewState *state = [self revenant_state];
    CGFloat rotation = state.rotateEnabled ? [state revenant_contentRotation] : 0.0;
    CGFloat pitch = state.pitchEnabled ? [state revenant_contentPitch] : 0.0;
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
    CATransform3D upright = CATransform3DInvert(CATransform3DMakeRotation(rotation, 0.0, 0.0, 1.0));
    for (id annotation in self.annotations) {
        MKAnnotationView *view = [self viewForAnnotation:annotation];
        if (view && [view isKindOfClass:[MKAnnotationView class]]) {
            view.layer.transform = upright;
        }
    }
    [(MKCompassButton *)state.compass setCompassHeading:state.heading];
    [self revenant_updateControls];
}

- (void)revenant_startFollowingBounds
{
    if ([self revenant_link]) {
        return;
    }
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(revenant_followBounds:)];
    [self revenant_setLink:link];
    [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)revenant_followBounds:(CADisplayLink *)link
{
    RevenantMapViewState *state = [self revenant_state];
    if (state.rotateEnabled || state.pitchEnabled) {
        [self revenant_applyTransform];
        [self revenant_updateControls];
    }
}

#pragma mark - The rotation gesture

- (void)revenant_installGesture
{
    UIRotationGestureRecognizer *gesture = objc_getAssociatedObject(self, (const void *)"revenantRotationGesture");
    if (gesture) {
        return;
    }
    gesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_rotate:)];
    gesture.delegate = (id<UIGestureRecognizerDelegate>)self;
    [self addGestureRecognizer:gesture];
    objc_setAssociatedObject(self, (const void *)"revenantRotationGesture", gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)revenant_rotate:(UIRotationGestureRecognizer *)gesture
{
    RevenantMapViewState *state = [self revenant_state];
    if (gesture.state == UIGestureRecognizerStateChanged) {
        state.heading = (CGFloat)fmod((double)state.heading - (double)gesture.rotation * 180.0 / M_PI + 360.0, 360.0);
        gesture.rotation = 0.0;
        [self revenant_applyTransform];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture
{
    if ([gesture isKindOfClass:[UIRotationGestureRecognizer class]]) {
        return [self revenant_state].rotateEnabled;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    return [gesture isKindOfClass:[UIRotationGestureRecognizer class]];
}

#pragma mark - The properties

- (BOOL)rotateEnabled
{
    return [self revenant_state].rotateEnabled;
}

- (void)setRotateEnabled:(BOOL)rotateEnabled
{
    [self revenant_state].rotateEnabled = rotateEnabled;
    if (rotateEnabled) {
        [self revenant_installGesture];
    }
    [self revenant_applyTransform];
}

- (BOOL)pitchEnabled
{
    return [self revenant_state].pitchEnabled;
}

- (void)setPitchEnabled:(BOOL)pitchEnabled
{
    RevenantMapViewState *state = [self revenant_state];
    state.pitchEnabled = pitchEnabled;
    if (pitchEnabled && state.eyeDistance <= 0.0) {
        state.eyeDistance = MAX(400.0, [self revenant_metresAcross]);
    }
    if (pitchEnabled) {
        [self revenant_startFollowingBounds];
    }
    [self revenant_applyTransform];
}

- (CLLocationDirection)revenant_heading
{
    return (CLLocationDirection)[self revenant_state].heading;
}

- (CGFloat)revenant_pitch
{
    return [self revenant_state].pitch;
}

- (void)revenant_setHeading:(CLLocationDirection)heading pitch:(CGFloat)pitch
{
    RevenantMapViewState *state = [self revenant_state];
    state.heading = (CGFloat)fmod((double)heading, 360.0);
    state.pitch = MAX(0.0, MIN(90.0, (CGFloat)pitch));
    if (state.pitch > 0.0) {
        state.pitchEnabled = YES;
        if (state.eyeDistance <= 0.0) {
            state.eyeDistance = MAX(400.0, [self revenant_metresAcross]);
        }
        [self revenant_startFollowingBounds];
    }
    [self revenant_applyTransform];
}

- (CGFloat)revenant_metresAcross
{
    MKMapRect visible = self.visibleMapRect;
    if (visible.size.width <= 0.0) {
        return 2000.0;
    }
    return (CGFloat)(visible.size.width * MKMetersPerMapPointAtLatitude(self.centerCoordinate.latitude));
}

- (BOOL)showsCompass
{
    return [self revenant_state].showsCompass;
}

- (void)setShowsCompass:(BOOL)showsCompass
{
    RevenantMapViewState *state = [self revenant_state];
    state.showsCompass = showsCompass;
    [self revenant_updateControls];
}

- (BOOL)showsScale
{
    return [self revenant_state].showsScale;
}

- (void)setShowsScale:(BOOL)showsScale
{
    RevenantMapViewState *state = [self revenant_state];
    state.showsScale = showsScale;
    [self revenant_updateControls];
}

- (BOOL)showsUserTrackingButton
{
    return [self revenant_state].showsUserTrackingButton;
}

- (void)setShowsUserTrackingButton:(BOOL)showsUserTrackingButton
{
    RevenantMapViewState *state = [self revenant_state];
    state.showsUserTrackingButton = showsUserTrackingButton;
    [self revenant_updateControls];
}

- (MKFeatureVisibility)pitchButtonVisibility
{
    return (MKFeatureVisibility)[self revenant_state].pitchButtonVisibility;
}

- (void)setPitchButtonVisibility:(MKFeatureVisibility)pitchButtonVisibility
{
    [self revenant_state].pitchButtonVisibility = pitchButtonVisibility;
    [self revenant_inert:@"MKMapView.pitchButtonVisibility"
                  why:@"the release's map view has no pitch button: its own public surface (228 methods, measured) is a region, a map type and the user location"];
}

- (BOOL)selectableMapFeatures
{
    return [self revenant_state].selectableMapFeatures;
}

- (void)setSelectableMapFeatures:(BOOL)selectableMapFeatures
{
    [self revenant_state].selectableMapFeatures = selectableMapFeatures;
    [self revenant_inert:@"MKMapView.selectableMapFeatures"
                  why:@"the release's map view has no selectable features at all: it has no selection of its own, and the features a selection would choose between arrive with a map the release does not have"];
}

- (BOOL)showsTraffic
{
    return [self revenant_state].showsTraffic != 0;
}

- (void)setShowsTraffic:(BOOL)showsTraffic
{
    [self revenant_state].showsTraffic = showsTraffic ? 1 : 0;
    [self revenant_inert:@"MKMapView.showsTraffic"
                  why:@"the release's map draws one fixed tile style and has no traffic layer to draw or not: -showsTraffic is not in its 228 public methods (measured) and its own trafficEnabled spelling belongs to another class"];
}

- (BOOL)showsBuildings
{
    return [self revenant_state].showsBuildings != 0;
}

- (void)setShowsBuildings:(BOOL)showsBuildings
{
    [self revenant_state].showsBuildings = showsBuildings ? 1 : 0;
    [self revenant_inert:@"MKMapView.showsBuildings"
                  why:@"the release's map draws its buildings inside its own vector tiles, and there is no way to ask it for a style without them: the tile style is the release's own and this port has no way to vary it"];
}

- (BOOL)showsPointsOfInterest
{
    return [self revenant_state].showsPointsOfInterest != 0;
}

- (void)setShowsPointsOfInterest:(BOOL)showsPointsOfInterest
{
    [self revenant_state].showsPointsOfInterest = showsPointsOfInterest ? 1 : 0;
    [self revenant_inert:@"MKMapView.showsPointsOfInterest"
                  why:@"the release's map draws its points of interest inside its own vector tiles, and there is no way to ask it for a style without them"];
}

- (MKPointOfInterestFilter *)pointOfInterestFilter
{
    return [self revenant_state].pointOfInterestFilter;
}

- (void)setPointOfInterestFilter:(MKPointOfInterestFilter *)filter
{
    [self revenant_state].pointOfInterestFilter = filter;
    [self revenant_inert:@"MKMapView.pointOfInterestFilter"
                  why:@"the release's map draws its points of interest from its own tiles and takes no filter, so there is nothing for a filter to act on"];
}

- (void)revenant_inert:(NSString *)api why:(NSString *)why
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

- (void)revenant_updateControls
{
    RevenantMapViewState *state = [self revenant_state];
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
    return [self revenant_state].cameraBoundary;
}

- (MKCoordinateRegion)revenant_boundedRegion
{
    MKMapCameraBoundary *boundary = [self revenant_state].cameraBoundary;
    MKMapRect rect = boundary ? boundary.mapRect : MKMapRectWorld;
    return MKCoordinateRegionForMapRect(rect);
}

- (void)setCameraBoundary:(MKMapCameraBoundary *)cameraBoundary
{
    [self revenant_state].cameraBoundary = cameraBoundary;
}

- (void)setCameraBoundary:(MKMapCameraBoundary *)cameraBoundary animated:(BOOL)animated
{
    [self setCameraBoundary:cameraBoundary];
    [self revenant_applyCameraAnimated:animated];
}

- (MKMapCameraZoomRange *)cameraZoomRange
{
    return [self revenant_state].cameraZoomRange;
}

- (void)setCameraZoomRange:(MKMapCameraZoomRange *)cameraZoomRange
{
    [self revenant_state].cameraZoomRange = cameraZoomRange;
}

- (void)setCameraZoomRange:(MKMapCameraZoomRange *)cameraZoomRange animated:(BOOL)animated
{
    [self setCameraZoomRange:cameraZoomRange];
    [self revenant_applyCameraAnimated:animated];
}

- (MKCoordinateRegion)revenant_clampRegion:(MKCoordinateRegion)region
{
    MKCoordinateRegion bounded = [self revenant_boundedRegion];
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
    MKMapCameraZoomRange *zoom = [self revenant_state].cameraZoomRange;
    if (zoom) {
        double metresAcross = (double)[self revenant_metresAcross];
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

- (void)revenant_applyCameraAnimated:(BOOL)animated
{
    MKMapCamera *camera = self.camera;
    if (!camera) {
        return;
    }
    MKMapPoint centre = MKMapPointForCoordinate(camera.centerCoordinate);
    double metresPerPoint = MKMetersPerMapPointAtLatitude(camera.centerCoordinate.latitude);
    double distance = camera.centerCoordinateDistance > 0.0 ? camera.centerCoordinateDistance : 1000.0;
    MKMapRect rect = MKMapRectMake(centre.x, centre.y, metresPerPoint > 0.0 ? distance / metresPerPoint : 0.0,
                                   metresPerPoint > 0.0 ? distance / metresPerPoint : 0.0);
    [self setRegion:[self revenant_clampRegion:MKCoordinateRegionForMapRect(rect)] animated:animated];
}

#pragma mark - The configuration and the map type

- (MKMapConfiguration *)preferredConfiguration
{
    MKMapConfiguration *configuration = [self revenant_state].preferredConfiguration;
    if (!configuration) {
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
        [self revenant_state].preferredConfiguration = configuration;
    }
    return configuration;
}

- (void)setPreferredConfiguration:(MKMapConfiguration *)preferredConfiguration
{
    [self revenant_state].preferredConfiguration = preferredConfiguration;
    if ([preferredConfiguration isKindOfClass:[MKHybridMapConfiguration class]]) {
        self.mapType = MKMapTypeHybrid;
    } else if ([preferredConfiguration isKindOfClass:[MKImageryMapConfiguration class]]) {
        self.mapType = MKMapTypeSatellite;
    } else if ([preferredConfiguration isKindOfClass:[MKStandardMapConfiguration class]]) {
        self.mapType = MKMapTypeStandard;
    }
}

@end
