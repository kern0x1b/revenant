#import <MapKit/MapKit.h>
#import <MapKit/MKMapSnapshotter.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "RevenantMapKit.h"

@interface MKMapSnapshotOptions ()
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
    MKMapRect _revenant_rect;
    BOOL _revenant_rect_set;
}

@synthesize image = _image;

- (instancetype)initWithImage:(UIImage *)image mapRect:(MKMapRect)mapRect
{
    self = [super init];
    if (self) {
        _image = image;
        _revenant_rect = mapRect;
        _revenant_rect_set = YES;
    }
    return self;
}

- (CGPoint)pointForCoordinate:(CLLocationCoordinate2D)coordinate
{
    MKMapRect rect = _revenant_rect_set ? _revenant_rect : MKMapRectWorld;
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

- (void)startWithQueue:(dispatch_queue_t)queue completionHandler:(void (^)(MKMapSnapshot *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    if (_loading) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, [self revenant_errorForReason:@"MKMapSnapshotter is already loading"]);
        });
        return;
    }
    _loading = YES;
    dispatch_queue_t work = queue;
    if (!work) {
        work = dispatch_queue_create("org.revenant.backports.MapKitSnapshotter", DISPATCH_QUEUE_SERIAL);
    }

    dispatch_async(work, ^{
        MKMapSnapshot *snapshot = [self revenant_snapshot];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_loading = NO;
            if (snapshot) {
                completionHandler(snapshot, nil);
            } else {
                completionHandler(nil, [self revenant_errorForReason:@"the map view of the release drew no image"]);
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

- (NSError *)revenant_errorForReason:(NSString *)reason
{
    return [NSError errorWithDomain:@"MKErrorDomain" code:1
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

- (MKMapSnapshot *)revenant_snapshot
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
    MKMapCamera *camera = options.camera;
    if (camera) {
        [mapView setCamera:camera animated:NO];
    } else {
        [mapView setRegion:options.region animated:NO];
    }
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.35]];
    CGSize drawn = CGSizeMake(size.width * scale, size.height * scale);
    UIGraphicsBeginImageContextWithOptions(drawn, NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context) {
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
