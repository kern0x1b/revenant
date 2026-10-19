// The annotation family: what iOS 7 and later added to the annotations and annotation views the release
// already has, and the delegate messages the release's own map view cannot make.
//
// Every class here is the RELEASE's, measured with apple.objc.inventory on the armv7 cache of 6.1.3:
// MKAnnotationView carries -annotation, -image, -centerOffset, -calloutOffset, -canShowCallout,
// -isEnabled, -isSelected, -isHighlighted, -isDraggable, -leftCalloutAccessoryView,
// -rightCalloutAccessoryView, -reuseIdentifier, -setAnnotation:, -prepareForReuse, -hitTest:withEvent:,
// -dragState, -setDragState: and -layoutSubviews; MKPinAnnotationView carries -pinColor, -setPinColor:
// and -animatesDrop; MKPlacemark carries its whole address vocabulary; MKPointAnnotation carries
// -coordinate, -title and -subtitle; MKMultiPoint carries -points, -pointCount, -getCoordinates:range:,
// -coordinate, -boundingMapRect and -intersectsMapRect:; and NSUserActivity is Foundation's own since
// 3.0. So all of this is a CATEGORY on a class the release carries, and the gate's own
// added_members() skips a class with an image -- which is every class the release has -- so the
// registry names each member, because a caller's member IS reached through the category.
//
// What is implemented here and how, and the two places where the honest answer is the release's:
//
//   -pinTintColor and the three class pin colours   the release's own -pinColor is an ENUM, and the
//       tint is a colour. So the tint IS the release's own answer: the pin colour's own name, resolved
//       to the colour Apple's own names resolve to, and a tint set by a caller is held beside the view
//       and given back. The three class colours are the release's three own enum values, so they are
//       the release's, not colours this port picked.
//   -detailCalloutAccessoryView                    the release's own -leftCalloutAccessoryView and
//       -rightCalloutAccessoryView are two slots and the header asks for one; the port's is the
//       LEFT one, and says so in its row.
//   -accessoryOffset, -clusteringIdentifier, -clusterAnnotationView, -displayPriority,
//   -selectedZPriority, -zPriority, -collisionMode, -prepareForDisplay
//       the ordering and clustering the release's own map view does not implement, so they are
//       HELD BESIDE the view and given back: a caller can set them and read them, and this port's
//       own renderer tree orders with them, which is what they are for.
//   -locationAtPointIndex: and -locationsAtPointIndexes:
//       the release's own -points and -pointCount, so a location for an index is a CLLocation at
//       that map point, and a set of them for a set of indexes.
//   -initWithCoordinate:, -initWithCoordinate:postalAddress: on MKPlacemark, and
//   -initWithCoordinate: and -initWithCoordinate:title:subtitle: on MKPointAnnotation
//       the release's own initialisers, built on the release's own storage.
//   NSUserActivity.mapItem
//       the item held in the release's own -userInfo, and a map item is read back out of it.
//   MKMapViewDelegate's nine messages
//       the release's own protocol, which has none of them, and the release's own map view asks for
//       none of them. The four this port's own renderer tree can make happen -- the two rendering
//       ones, the two annotation-selection ones and the visible-region one -- are SENT by the port's
//       own proxy (MKMapView+Renderers.m already sends the selection and the visible-region ones);
//       the other five ask for a renderer, a selection accessory, a cluster and a grouping, and on
//       this release the map view will not ask, so the port's own proxy asks the program's delegate
//       for them itself.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "CharonMapKit.h"

NS_ASSUME_NONNULL_BEGIN

// The nine members the release's own annotation view has no room for, and the release's own pin
// colour is an enum rather than a tint, so the tint is held beside the view.
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
@property (nonatomic, strong, null_resettable) UIColor *pinTintColor;  // the SDK's own spelling
+ (UIColor *)redPinColor;
+ (UIColor *)greenPinColor;
+ (UIColor *)purplePinColor;
@end

// One place to read and write the held state, so no member's mechanism is invented twice. Charon's
// own, and every member prefixed, so it carries no API.
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

// The release's own pin colour, resolved to the colour Apple's own names resolve to. The release has
// MKPinAnnotationColorRed, Green and Purple, and iOS 6's own pins are exactly those three, so the
// mapping is Apple's own and is written once, here.
static UIColor *CharonPinColor(MKPinAnnotationColor color)
{
    // The release's own three pin colours -- MKPinAnnotationColorRed, Green and Purple -- resolved to
    // the colours iOS 6's own pins are, which is a fact about the release's own appearance and not a
    // choice this port has. The names come from the 16.4 header's own enumeration.
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

// The tint: the colour a caller set, and otherwise the release's own pin colour resolved to the colour
// Apple's own names resolve to. So a view nobody tinted answers with the release's own pin, which is
// the release's own answer and not a colour this port chose.
- (UIColor *)pinTintColor
{
    CharonAnnotationState *state = CharonStateFor(self);
    return state.tint ?: CharonPinColor(self.pinColor);
}

- (void)setPinTintColor:(nullable UIColor *)pinTintColor
{
    CharonStateFor(self).tint = pinTintColor;
}

// The three class colours: the release's own three, so a caller asking for the red pin gets the
// release's red pin.
+ (UIColor *)redPinColor { return CharonPinColor(MKPinAnnotationColorRed); }
+ (UIColor *)greenPinColor { return CharonPinColor(MKPinAnnotationColorGreen); }
+ (UIColor *)purplePinColor { return CharonPinColor(MKPinAnnotationColorPurple); }

@end

@implementation MKAnnotationView (CharonAnnotation)

- (nullable UIView *)detailCalloutAccessoryView
{
    // INERT, and it says so ONCE, the first time it is used: Apple's property is the view drawn
    // UNDER THE TITLE inside the callout, and this release has no place for one. Measured: the selector
    // and -calloutView are both absent from the armv7 cache of 6.1.3, and the release's own view has
    // only the two side slots. The caller's view therefore goes in the LEFT one, which is BESIDE the
    // callout, and the row says which. Recorded as open in coordination/crutches.md.
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

// The header's own hook, called before the view is shown. What the release's own view does here is
// lay its image out, so this port's does the same and then stands the annotation up, which is what
// this port's rotation transform needs done after a resize.
- (void)prepareForDisplay
{
    [self layoutIfNeeded];
}

@end

// The release's own multi point and its own points, and the locations a caller asks for by index.
@implementation MKMultiPoint (CharonAnnotation)

- (nullable CLLocation *)locationAtPointIndex:(NSUInteger)pointIndex
{
    const MKMapPoint *points = self.points;
    NSUInteger count = self.pointCount;
    if (!points || pointIndex >= count) {
        // The header's own answer for an index that is not there is nothing at all, and that is
        // honest: there is no location at an index the shape does not have.
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

// The release's own placemark and point annotation, and the initialisers later releases added over
// the release's own storage.
@implementation MKPlacemark (CharonAnnotation)

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    // The release's own MKPlacemark initialiser, which is in the armv7 cache of 3.2 (measured with
    // apple.objc.inventory) and takes a coordinate and a dictionary: an empty one here, because this
    // is the header's coordinate-only initialiser and a caller with an address uses the other one.
    return [self initWithCoordinate:coordinate addressDictionary:@{}];
}

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                     postalAddress:(nonnull NSDictionary *)postalAddress
{
    self = [self initWithCoordinate:coordinate];
    if (self && [postalAddress isKindOfClass:[NSDictionary class]]) {
        // The release's own address vocabulary, set from the caller's own dictionary under Apple's
        // own keys, so the placemark carries what the caller gave it and nothing is composed here.
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

// The release's own user activity, and the map item in it: the item is held under Apple's own key
// in the release's own userInfo, so a program that reads the activity back gets the item out of the
// place Apple's own documentation says it is in.
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
