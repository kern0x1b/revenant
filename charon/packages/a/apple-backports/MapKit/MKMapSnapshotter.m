// MKMapSnapshotOptions, MKMapSnapshot and MKMapSnapshotter: a map drawn once, off screen, with no
// map view on screen and nothing asked of the user.
//
// The snapshotter is built on the release's own MKMapView, which is the only map this port has: a
// map view the size the options ask for, put in a window of its own off screen, given the region
// and the map type the options ask for, asked to draw itself, and then the pixels it drew are read
// out. That is a real map, drawn by the release's own renderer, with the release's own tiles --
// not a reimplementation of one. The map view is torn down as soon as the pixels are in hand, so a
// program that takes many snapshots does not accumulate map views.
#import <MapKit/MapKit.h>
#import <MapKit/MKMapSnapshotter.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "CharonMapKit.h"

// The 16.0 configuration the 16.4 header does not declare: which map the snapshot is a snapshot of.
@interface MKMapSnapshotOptions ()
@property (nonatomic, copy) MKMapConfiguration *preferredConfiguration;
@end

@implementation MKMapSnapshotOptions {
    CGSize _size;
    MKMapType _mapType;
    MKMapRect _mapRect;
    MKCoordinateRegion _region;
    CGFloat _scale;
    MKMapCamera *_camera;
    MKMapConfiguration *_preferredConfiguration;
    MKPointOfInterestFilter *_pointOfInterestFilter;
    BOOL _showsBuildings;
    BOOL _showsPointsOfInterest;
}

@synthesize size = _size;
@synthesize mapType = _mapType;
@synthesize mapRect = _mapRect;
@synthesize region = _region;
@synthesize scale = _scale;
@synthesize camera = _camera;
@synthesize preferredConfiguration = _preferredConfiguration;
@synthesize pointOfInterestFilter = _pointOfInterestFilter;
@synthesize showsBuildings = _showsBuildings;
@synthesize showsPointsOfInterest = _showsPointsOfInterest;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _size = CGSizeMake(256.0, 256.0);
        _mapType = MKMapTypeStandard;
        _mapRect = MKMapRectWorld;
        _region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(0.0, 0.0), MKCoordinateSpanMake(180.0, 360.0));
        _scale = 1.0;
        _showsBuildings = YES;
        _showsPointsOfInterest = YES;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MKMapSnapshotOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.size = _size;
    copy.mapType = _mapType;
    copy.mapRect = _mapRect;
    copy.region = _region;
    copy.scale = _scale;
    copy.showsBuildings = _showsBuildings;
    copy.showsPointsOfInterest = _showsPointsOfInterest;
    copy.preferredConfiguration = _preferredConfiguration;
    copy.pointOfInterestFilter = _pointOfInterestFilter;
    return copy;
}

- (void)setPreferredConfiguration:(MKMapConfiguration *)configuration
{
    _preferredConfiguration = configuration;
}

- (void)setPointOfInterestFilter:(MKPointOfInterestFilter *)filter
{
    _pointOfInterestFilter = filter;
}

- (MKPointOfInterestFilter *)pointOfInterestFilter
{
    return _pointOfInterestFilter;
}

@end

@implementation MKMapSnapshot {
    UIImage *_image;
    MKMapRect _charon_rect;
    BOOL _charon_rect_set;
}

@synthesize image = _image;

// The snapshot of an image of a known map rect, which is the pair the point-for-coordinate answer
// needs. Charon's own, so it carries no API.
- (instancetype)initWithImage:(UIImage *)image mapRect:(MKMapRect)mapRect
{
    self = [super init];
    if (self) {
        _image = image;
        _charon_rect = mapRect;
        _charon_rect_set = YES;
    }
    return self;
}

- (CGPoint)pointForCoordinate:(CLLocationCoordinate2D)coordinate
{
    // Where a coordinate ended up in the image: the release's own projection puts it in the
    // snapshot's map rect, and the map rect fills the image.
    MKMapRect rect = _charon_rect_set ? _charon_rect : MKMapRectWorld;
    MKMapPoint point = MKMapPointForCoordinate(coordinate);
    CGFloat width = _image ? (CGFloat)_image.size.width * _image.scale : 0.0;
    CGFloat height = _image ? (CGFloat)_image.size.height * _image.scale : 0.0;
    if (rect.size.width <= 0.0 || rect.size.height <= 0.0 || width <= 0.0 || height <= 0.0) {
        return CGPointZero;
    }
    return CGPointMake((CGFloat)((point.x - rect.origin.x) / rect.size.width) * width,
                       (CGFloat)((point.y - rect.origin.y) / rect.size.height) * height);
}

@end

@implementation MKMapSnapshotter {
    MKMapSnapshotOptions *_options;
    BOOL _loading;
}

@synthesize loading = _loading;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _options = [[MKMapSnapshotOptions alloc] init];
        _loading = NO;
    }
    return self;
}

- (instancetype)initWithOptions:(MKMapSnapshotOptions *)options
{
    self = [self init];
    if (self) {
        if (options) {
            _options = options;
        }
    }
    return self;
}

// The work, off the caller's thread: the header says the snapshotter starts the work on a queue of
// the caller's choosing and answers on the main queue, and a queue of nil means the snapshotter's
// own, so both are honoured here -- the drawing happens on the queue that was given, and the answer
// comes back on the main queue.
- (void)startWithQueue:(dispatch_queue_t)queue completionHandler:(void (^)(MKMapSnapshot *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    if (_loading) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, [self charon_errorForReason:@"MKMapSnapshotter is already loading"]);
        });
        return;
    }
    _loading = YES;
    dispatch_queue_t work = queue;
    if (!work) {
        work = dispatch_queue_create("org.charon.apple-backports.MapKitSnapshotter", DISPATCH_QUEUE_SERIAL);
    }

    dispatch_async(work, ^{
        MKMapSnapshot *snapshot = [self charon_snapshot];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_loading = NO;
            if (snapshot) {
                completionHandler(snapshot, nil);
            } else {
                completionHandler(nil, [self charon_errorForReason:@"the map view of the release drew no image"]);
            }
        });
    });
}

- (void)startWithCompletionHandler:(void (^)(MKMapSnapshot *, NSError *))completionHandler
{
    [self startWithQueue:nil completionHandler:completionHandler];
}

- (void)cancel
{
    _loading = NO;
}

- (NSError *)charon_errorForReason:(NSString *)reason
{
    return [NSError errorWithDomain:@"MKErrorDomain" code:1
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

// The snapshot itself: the release's own map view, off screen, drawn. Charon's own, so it carries
// no API.
- (MKMapSnapshot *)charon_snapshot
{
    MKMapSnapshotOptions *options = _options;
    if (!options) {
        return nil;
    }
    CGSize size = options.size;
    if (size.width <= 0.0 || size.height <= 0.0) {
        return nil;
    }
    CGFloat scale = options.scale > 0.0 ? options.scale : 1.0;
    UIWindow *window = nil;
    if ([UIWindow class]) {
        window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
    }
    MKMapView *mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
    mapView.mapType = options.mapType;
    if (window) {
        [window addSubview:mapView];
        [window makeKeyAndVisible];
    } else {
        [mapView setNeedsDisplay];
    }
    // A camera, when the options carry one, and a region otherwise: the two say the same thing on
    // a map view whose own region is what the release lays its tiles out from.
    MKMapCamera *camera = options.camera;
    if (camera) {
        [mapView setCamera:camera animated:NO];
    } else {
        [mapView setRegion:options.region animated:NO];
    }
    // The renderer draws its tiles as they arrive, so the map is given a moment of its own to do it
    // before the pixels are read. One run loop turn is what the release's own map view needs for a
    // tile it already has; a snapshot of tiles it has not asked for yet is a snapshot of the map
    // with the tiles it had, which is what a map view off screen can be.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.35]];
    CGSize drawn = CGSizeMake(size.width * scale, size.height * scale);
    UIGraphicsBeginImageContextWithOptions(drawn, NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context) {
        // The map view's own layer tree is what is drawn into the context, so what lands in the
        // image is what the release's map view drew and not a copy of it.
        [mapView.layer renderInContext:context];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [mapView removeFromSuperview];
    [window resignKeyWindow];
    if (!image) {
        return nil;
    }
    return [[MKMapSnapshot alloc] initWithImage:image mapRect:options.mapRect];
}

@end
