#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

static NSError *MKCharonNoCoverage(NSString *what)
{
    return [NSError errorWithDomain:@"MKErrorDomain" code:1
                           userInfo:@{NSLocalizedDescriptionKey:
                                          [NSString stringWithFormat:
                                           @"%@ has no coverage on this port: Look Around is Apple's own "
                                           @"street-level imagery, served by Apple's own service, and "
                                           @"there is no public web API for it and nothing on the device "
                                           @"that holds a panorama, so there is no scene to give", what]}];
}

@interface MKLookAroundSceneRequest (CharonCoverage)
+ (BOOL)isAvailable;
@end

@implementation MKLookAroundSceneRequest {
    CLLocationCoordinate2D _coordinate;
    BOOL _loading;
    BOOL _cancelled;
}

@synthesize coordinate = _coordinate;
@synthesize loading = _loading;
@synthesize cancelled = _cancelled;

+ (BOOL)isAvailable
{
    return NO;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _coordinate = kCLLocationCoordinate2DInvalid;
    }
    return self;
}

- (instancetype)initWithMapItem:(MKMapItem *)mapItem
{
    self = [self init];
    if (self) {
        id item = mapItem;
        if (item && [item respondsToSelector:@selector(placemark)]) {
            id (*placemark)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
            id place = placemark(item, @selector(placemark));
            CLLocationCoordinate2D (*coordinate)(id, SEL) = (CLLocationCoordinate2D (*)(id, SEL))objc_msgSend;
            if (place) {
                _coordinate = coordinate(place, @selector(coordinate));
            }
        }
    }
    return self;
}

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    self = [self init];
    if (self) {
        _coordinate = coordinate;
    }
    return self;
}

- (void)getSceneWithCompletionHandler:(void (^)(MKLookAroundScene *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    _loading = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(nil, MKCharonNoCoverage(@"MKLookAroundSceneRequest"));
    });
}

- (void)cancel
{
    _cancelled = YES;
    _loading = NO;
}

@end

@implementation MKLookAroundScene {
    CLLocationCoordinate2D _centerCoordinate;
}

- (CLLocationCoordinate2D)centerCoordinate
{
    return _centerCoordinate;
}

@end

@implementation MKLookAroundSnapshotOptions {
    CGSize _size;
    MKPointOfInterestFilter *_pointOfInterestFilter;
}

@synthesize size = _size;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _size = CGSizeMake(256.0, 256.0);
    }
    return self;
}

- (MKPointOfInterestFilter *)pointOfInterestFilter
{
    return _pointOfInterestFilter;
}

- (void)setPointOfInterestFilter:(MKPointOfInterestFilter *)filter
{
    _pointOfInterestFilter = [filter copy];
}

@end

@implementation MKLookAroundSnapshot

- (instancetype)init
{
    return [super init];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (UIImage *)image
{
    return nil;
}

@end

@implementation MKLookAroundSnapshotter {
    MKLookAroundScene *_scene;
    MKLookAroundSnapshotOptions *_options;
    BOOL _loading;
}

@synthesize loading = _loading;

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithScene:(MKLookAroundScene *)scene
{
    return [self initWithScene:scene options:[[MKLookAroundSnapshotOptions alloc] init]];
}

- (instancetype)initWithScene:(MKLookAroundScene *)scene options:(MKLookAroundSnapshotOptions *)options
{
    self = [self init];
    if (self) {
        _scene = scene;
        _options = options;
    }
    return self;
}

- (MKLookAroundSnapshotOptions *)options
{
    return _options;
}

- (void)getSnapshotWithCompletionHandler:(void (^)(MKLookAroundSnapshot *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(nil, MKCharonNoCoverage(@"MKLookAroundSnapshotter"));
    });
}

- (void)cancel
{
    _loading = NO;
}

@end

@implementation MKLookAroundViewController {
    MKLookAroundScene *_scene;
    __weak id<MKLookAroundViewControllerDelegate> _delegate;
    BOOL _navigationEnabled;
    MKPointOfInterestFilter *_pointOfInterestFilter;
    MKLookAroundBadgePosition _badgePosition;
    BOOL _showsRoadLabels;
}

@synthesize scene = _scene;
@synthesize delegate = _delegate;
@synthesize navigationEnabled = _navigationEnabled;
@synthesize badgePosition = _badgePosition;
@synthesize showsRoadLabels = _showsRoadLabels;

- (instancetype)initWithScene:(MKLookAroundScene *)scene
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _scene = scene;
        [self charon_reportTheUpdate];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _scene = nil;
        [self charon_reportTheUpdate];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _scene = nil;
        [self charon_reportTheUpdate];
    }
    return self;
}

- (void)charon_reportTheUpdate
{
    id<MKLookAroundViewControllerDelegate> delegate = _delegate;
    void (*send)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
    if ([delegate respondsToSelector:@selector(lookAroundViewControllerWillUpdateScene:)]) {
        send(delegate, @selector(lookAroundViewControllerWillUpdateScene:), self);
    }
    if ([delegate respondsToSelector:@selector(lookAroundViewControllerDidUpdateScene:)]) {
        send(delegate, @selector(lookAroundViewControllerDidUpdateScene:), self);
    }
}

- (void)setDelegate:(id<MKLookAroundViewControllerDelegate>)delegate
{
    _delegate = delegate;
    [self charon_reportTheUpdate];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self charon_reportTheUpdate];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    id<MKLookAroundViewControllerDelegate> delegate = _delegate;
    SEL dismissed = @selector(lookAroundViewControllerDidDismissFullScreen:);
    if ([delegate respondsToSelector:dismissed]) {
        void (*send)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
        send(delegate, dismissed, self);
    }
}

- (void)setPointOfInterestFilter:(MKPointOfInterestFilter *)filter
{
    _pointOfInterestFilter = [filter copy];
}

@end
