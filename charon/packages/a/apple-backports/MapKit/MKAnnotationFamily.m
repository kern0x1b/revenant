#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "CharonMapKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKAnnotationView (CharonAnnotation)
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

@interface MKPinAnnotationView (CharonAnnotation)
@property (nonatomic, strong, null_resettable) UIColor *pinTintColor;
+ (UIColor *)redPinColor;
+ (UIColor *)greenPinColor;
+ (UIColor *)purplePinColor;
@end

@interface CharonAnnotationState : NSObject
@property (nonatomic, strong) UIColor *tint;
@property (nonatomic, copy) NSString *clusteringIdentifier;
@property (nonatomic, weak) MKAnnotationView *clusterView;
@property (nonatomic, assign) NSInteger displayPriority;
@property (nonatomic, assign) NSInteger selectedZPriority;
@property (nonatomic, assign) NSInteger zPriority;
@property (nonatomic, assign) NSInteger collisionMode;
@property (nonatomic, assign) CGPoint accessoryOffset;
@end

@implementation CharonAnnotationState
@synthesize tint = _tint;
@synthesize clusteringIdentifier = _clusteringIdentifier;
@synthesize clusterView = _clusterView;
@synthesize displayPriority = _displayPriority;
@synthesize selectedZPriority = _selectedZPriority;
@synthesize zPriority = _zPriority;
@synthesize collisionMode = _collisionMode;
@synthesize accessoryOffset = _accessoryOffset;
@end

static UIColor *CharonPinColor(MKPinAnnotationColor color)
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

static CharonAnnotationState *CharonStateFor(id view)
{
    static const void *key = &key;
    CharonAnnotationState *state = objc_getAssociatedObject(view, key);
    if (!state) {
        state = [[CharonAnnotationState alloc] init];
        objc_setAssociatedObject(view, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

@implementation MKPinAnnotationView (CharonAnnotation)

- (UIColor *)pinTintColor
{
    CharonAnnotationState *state = CharonStateFor(self);
    return state.tint ?: CharonPinColor(self.pinColor);
}

- (void)setPinTintColor:(nullable UIColor *)pinTintColor
{
    CharonStateFor(self).tint = pinTintColor;
}

+ (UIColor *)redPinColor { return CharonPinColor(MKPinAnnotationColorRed); }
+ (UIColor *)greenPinColor { return CharonPinColor(MKPinAnnotationColorGreen); }
+ (UIColor *)purplePinColor { return CharonPinColor(MKPinAnnotationColorPurple); }

@end

@implementation MKAnnotationView (CharonAnnotation)

- (nullable UIView *)detailCalloutAccessoryView
{
    charon_sayOnce(@"MKAnnotationView.detailCalloutAccessoryView",
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

- (nullable NSString *)clusteringIdentifier { return CharonStateFor(self).clusteringIdentifier; }
- (void)setClusteringIdentifier:(nullable NSString *)clusteringIdentifier
{
    CharonStateFor(self).clusteringIdentifier = clusteringIdentifier;
}

- (nullable MKAnnotationView *)clusterAnnotationView { return CharonStateFor(self).clusterView; }
- (void)charon_setClusterAnnotationView:(nullable MKAnnotationView *)view
{
    CharonStateFor(self).clusterView = view;
}

- (NSInteger)displayPriority { return CharonStateFor(self).displayPriority; }
- (void)setDisplayPriority:(NSInteger)displayPriority
{
    CharonStateFor(self).displayPriority = displayPriority;
}

- (NSInteger)zPriority { return CharonStateFor(self).zPriority; }
- (void)setZPriority:(NSInteger)zPriority { CharonStateFor(self).zPriority = zPriority; }
- (NSInteger)selectedZPriority { return CharonStateFor(self).selectedZPriority; }
- (void)setSelectedZPriority:(NSInteger)selectedZPriority
{
    CharonStateFor(self).selectedZPriority = selectedZPriority;
}

- (NSInteger)collisionMode { return CharonStateFor(self).collisionMode; }
- (void)setCollisionMode:(NSInteger)collisionMode { CharonStateFor(self).collisionMode = collisionMode; }

- (CGPoint)accessoryOffset { return CharonStateFor(self).accessoryOffset; }
- (void)setAccessoryOffset:(CGPoint)accessoryOffset
{
    CharonStateFor(self).accessoryOffset = accessoryOffset;
}

- (void)prepareForDisplay
{
    [self layoutIfNeeded];
}

@end

@implementation MKMultiPoint (CharonAnnotation)

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

@implementation MKPlacemark (CharonAnnotation)

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

@implementation MKPointAnnotation (CharonAnnotation)

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

@implementation NSUserActivity (CharonAnnotation)

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
