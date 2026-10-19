// MKLookAroundScene, MKLookAroundSceneRequest, MKLookAroundSnapshot, MKLookAroundSnapshotOptions,
// MKLookAroundSnapshotter and MKLookAroundViewController: the six classes of a feature this port
// has no source for.
//
// Look Around is Apple's own street-level imagery, captured by Apple's own vehicles and served by
// Apple's own service. There is no public web API for it, no open equivalent, and nothing on this
// device that holds a panorama. So the seam is real and it is Apple's, and the answer is the one
// Apple gives where it has no coverage: a nil, with the documented error, and nothing invented.
//
// What each of the six does, exactly:
//
//   - a scene request answers nil and MKErrorUnknown's neighbour, and says so through the error;
//   - a scene has no coverage, so every part of it is the empty answer;
//   - a snapshotter answers nil with the same error and -cancel is real;
//   - a snapshot options object is a value, and builds for real, but the snapshot it asks for is nil;
//   - a view controller is a real view controller, and its delegate is told the update and the
//     dismissal the header describes, with the scene it was given (none).
//
// The honest check a caller can make is exactly the one Apple offers: there is no scene, so there is
// no coverage. `isAvailable` on a request of this port's own says NO, for the same reason and in the
// same terms the rest of this library uses.

#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

// The one error every answer here carries: no coverage, in Apple's own error domain and Apple's own
// code for an unknown failure, with the reason in the description. It is a function so that the six
// answers are literally the same error. Charon's own, so it carries no API.
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

// The one thing this port adds that the SDK's headers do not: whether a Look Around request could
// ever have an answer here, which is what Apple calls coverage. Declared and not implemented below.
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

// Coverage, and the answer: there is none here, for the reason MKCharonNoCoverage gives.
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

// The answer, on the main queue as the header says: nil and the reason. No delay, because there is
// nothing to wait for -- and nothing here pretends to be a network round trip.
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

// The image of a snapshot that was never taken: nil, which is what a class with no coverage gives and
// what the header's own image is documented to be when there is no snapshot to take.
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

// The header's own designated initialiser for the snapshotter: the scene and the options. A scene
// that exists is still a scene with no coverage, so the snapshot is the same nil either way; the
// options are kept, so a caller that reads them back gets what it set.
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

// The header's own designated initialiser: a real view controller, with the scene it was given (of
// which there is none) and the delegate told about it.
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
    // The delegate's own messages, sent for real: it will be told there is no scene, which is the
    // truth, and the view controller is a real view controller it can present and dismiss.
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
