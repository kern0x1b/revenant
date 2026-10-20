#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "RevenantMapKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKAnnotationView (RevenantAnnotation)
@property (nonatomic, strong, nullable) UIView *detailCalloutAccessoryView;
@property (nonatomic, copy, nullable) NSString *clusteringIdentifier;
@property (nonatomic, weak, readonly, nullable) MKAnnotationView *clusterAnnotationView;
@property (nonatomic, assign) NSInteger displayPriority;
@property (nonatomic, assign) NSInteger selectedZPriority;
@property (nonatomic, assign) NSInteger zPriority;
@property (nonatomic, assign) NSInteger collisionMode;
@property (nonatomic, assign) CGPoint accessoryOffset;
- (void)prepareForDisplay;
@end

@interface MKPinAnnotationView (RevenantAnnotation)
@property (nonatomic, strong, null_resettable) UIColor *pinTintColor;
+ (UIColor *)redPinColor;
+ (UIColor *)greenPinColor;
+ (UIColor *)purplePinColor;
@end

@interface RevenantAnnotationState : NSObject
@property (nonatomic, strong) UIColor *tint;
@property (nonatomic, copy) NSString *clusteringIdentifier;
@property (nonatomic, weak) MKAnnotationView *clusterView;
@property (nonatomic, assign) NSInteger displayPriority;
@property (nonatomic, assign) NSInteger selectedZPriority;
@property (nonatomic, assign) NSInteger zPriority;
@property (nonatomic, assign) NSInteger collisionMode;
@property (nonatomic, assign) CGPoint accessoryOffset;
@end

@implementation RevenantAnnotationState
@synthesize tint = _tint;
@synthesize clusteringIdentifier = _clusteringIdentifier;
@synthesize clusterView = _clusterView;
@synthesize displayPriority = _displayPriority;
@synthesize selectedZPriority = _selectedZPriority;
@synthesize zPriority = _zPriority;
@synthesize collisionMode = _collisionMode;
@synthesize accessoryOffset = _accessoryOffset;
@end

static UIColor *RevenantPinColor(MKPinAnnotationColor color)
{
    switch (color) {
        case MKPinAnnotationColorGreen:
            return [UIColor colorWithRed:0.13f green:0.60f blue:0.13f alpha:1.0f];
        case MKPinAnnotationColorPurple:
            return [UIColor colorWithRed:0.51f green:0.20f blue:0.60f alpha:1.0f];
        default:
            return [UIColor colorWithRed:0.77f green:0.16f blue:0.16f alpha:1.0f];
    }
}

static RevenantAnnotationState *RevenantStateFor(id view)
{
    static const void *key = &key;
    RevenantAnnotationState *state = objc_getAssociatedObject(view, key);
    if (!state) {
        state = [[RevenantAnnotationState alloc] init];
        objc_setAssociatedObject(view, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

@implementation MKPinAnnotationView (RevenantAnnotation)

- (UIColor *)pinTintColor
{
    RevenantAnnotationState *state = RevenantStateFor(self);
    return state.tint ?: RevenantPinColor(self.pinColor);
}

- (void)setPinTintColor:(nullable UIColor *)pinTintColor
{
    RevenantStateFor(self).tint = pinTintColor;
}

+ (UIColor *)redPinColor { return RevenantPinColor(MKPinAnnotationColorRed); }
+ (UIColor *)greenPinColor { return RevenantPinColor(MKPinAnnotationColorGreen); }
+ (UIColor *)purplePinColor { return RevenantPinColor(MKPinAnnotationColorPurple); }

@end

@implementation MKAnnotationView (RevenantAnnotation)

- (nullable UIView *)detailCalloutAccessoryView
{
    revenant_sayOnce(@"MKAnnotationView.detailCalloutAccessoryView",
                   @"it is answered from the release's LEFT callout accessory slot, which is beside the "
                   @"callout and not under its title, because iOS 6 has no detail area: the selector and "
                   @"-calloutView are both absent from the armv7 cache of 6.1.3, and the native fix -- a "
                   @"callout of this port's own -- is open in coordination/crutches.md");
    return self.leftCalloutAccessoryView;
}

- (void)setDetailCalloutAccessoryView:(nullable UIView *)detailCalloutAccessoryView
{
    self.leftCalloutAccessoryView = detailCalloutAccessoryView;
}

- (nullable NSString *)clusteringIdentifier { return RevenantStateFor(self).clusteringIdentifier; }
- (void)setClusteringIdentifier:(nullable NSString *)clusteringIdentifier
{
    RevenantStateFor(self).clusteringIdentifier = clusteringIdentifier;
}

- (nullable MKAnnotationView *)clusterAnnotationView { return RevenantStateFor(self).clusterView; }
- (void)revenant_setClusterAnnotationView:(nullable MKAnnotationView *)view
{
    RevenantStateFor(self).clusterView = view;
}

- (NSInteger)displayPriority { return RevenantStateFor(self).displayPriority; }
- (void)setDisplayPriority:(NSInteger)displayPriority
{
    RevenantStateFor(self).displayPriority = displayPriority;
}

- (NSInteger)zPriority { return RevenantStateFor(self).zPriority; }
- (void)setZPriority:(NSInteger)zPriority { RevenantStateFor(self).zPriority = zPriority; }
- (NSInteger)selectedZPriority { return RevenantStateFor(self).selectedZPriority; }
- (void)setSelectedZPriority:(NSInteger)selectedZPriority
{
    RevenantStateFor(self).selectedZPriority = selectedZPriority;
}

- (NSInteger)collisionMode { return RevenantStateFor(self).collisionMode; }
- (void)setCollisionMode:(NSInteger)collisionMode { RevenantStateFor(self).collisionMode = collisionMode; }

- (CGPoint)accessoryOffset { return RevenantStateFor(self).accessoryOffset; }
- (void)setAccessoryOffset:(CGPoint)accessoryOffset
{
    RevenantStateFor(self).accessoryOffset = accessoryOffset;
}

- (void)prepareForDisplay
{
    [self layoutIfNeeded];
}

@end

@implementation MKMultiPoint (RevenantAnnotation)

- (nullable CLLocation *)locationAtPointIndex:(NSUInteger)pointIndex
{
    const MKMapPoint *points = self.points;
    NSUInteger count = self.pointCount;
    if (!points || pointIndex >= count) {
        return nil;
    }
    CLLocationCoordinate2D coordinate = MKCoordinateForMapPoint(points[pointIndex]);
    return [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
}

- (NSArray<CLLocation *> *)locationsAtPointIndexes:(NSIndexSet *)pointIndexes
{
    NSMutableArray *locations = [NSMutableArray array];
    const MKMapPoint *points = self.points;
    NSUInteger count = self.pointCount;
    if (!points || !pointIndexes) {
        return locations;
    }
    [pointIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        if (index < count) {
            CLLocationCoordinate2D coordinate = MKCoordinateForMapPoint(points[index]);
            [locations addObject:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude]];
        }
    }];
    return locations;
}

@end

@implementation MKPlacemark (RevenantAnnotation)

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    return [self initWithCoordinate:coordinate addressDictionary:@{}];
}

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                     postalAddress:(nonnull NSDictionary *)postalAddress
{
    self = [self initWithCoordinate:coordinate];
    if (self && [postalAddress isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in [postalAddress allKeys]) {
            id value = [postalAddress objectForKey:key];
            if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                [self setValue:value forKey:key];
            }
        }
    }
    return self;
}

@end

@implementation MKPointAnnotation (RevenantAnnotation)

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    self = [super init];
    if (self) {
        [self setCoordinate:coordinate];
    }
    return self;
}

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                               title:(nullable NSString *)title
                            subtitle:(nullable NSString *)subtitle
{
    self = [self initWithCoordinate:coordinate];
    if (self) {
        self.title = title;
        self.subtitle = subtitle;
    }
    return self;
}

@end

@implementation NSUserActivity (RevenantAnnotation)

- (nullable MKMapItem *)mapItem
{
    NSDictionary *info = self.userInfo;
    id item = [info isKindOfClass:[NSDictionary class]] ? [info objectForKey:@"MKMapItem"] : nil;
    return [item isKindOfClass:[MKMapItem class]] ? item : nil;
}

- (void)setMapItem:(nullable MKMapItem *)mapItem
{
    NSMutableDictionary *info = [self.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
    if (mapItem) {
        [info setObject:mapItem forKey:@"MKMapItem"];
    } else {
        [info removeObjectForKey:@"MKMapItem"];
    }
    self.userInfo = info;
}

@end

NS_ASSUME_NONNULL_END
