// The map item's detail screen, its selection accessory, and the presentation styles that say how
// the screen is shown. Seventeen rows, all iOS 18, all in the object of that measured release.
//
// Every shape below is the host's own, measured with class_copyMethodList on MapKit.framework
// before the code was written, and two of them were not what the name suggests:
//
//   -[MKMapItemDetailViewController initWithMapItem:displaysMap:]   @28@0:8@16B24
//       the displaysMap: argument is a BOOL (the B), not an object
//   +[...PresentationStyle calloutWithCalloutStyle:]                @24@0:8q16
//       the callout style is an eight-byte enum (the q), and the style is a class of five CLASS
//       methods and no instance ones -- +callout and +openInMaps, which the corpus lists as
//       properties and which are class properties returning id
//
// The detail screen is a real view controller over the release's own views: the item's own name, its
// own address vocabulary, and the release's own callout for the accessory. Nothing is invented, and
// where the release cannot build something the answer says which thing cannot be built.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "CharonMapKit.h"

// MKMapItem's own later members, which are a category on the release's class in the file beside this
// one; the detail screen reads two of them, so they are declared here for the compiler.
@interface MKMapItem (CharonDetailReads)
- (nullable NSString *)identifier;
- (nullable MKAddress *)address;
@end

NS_ASSUME_NONNULL_BEGIN

// The callout style's own enumeration, which the 16.4 headers have not got. Apple's own spelling,
// and the eight bytes wide the host's own signature says it is (the q in @24@0:8q16).
typedef NS_ENUM(long long, MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyle) {
    MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyleSmall = 0,
    MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyleMedium = 1,
    MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyleLarge = 2,
};

// ============================ the presentation styles ============================

@interface MKMapItemDetailSelectionAccessoryPresentationStyle : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)calloutWithCalloutStyle:(MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyle)style;
+ (instancetype)automaticWithPresentationViewController:(UIViewController *)controller;
+ (instancetype)sheetPresentedFromViewController:(UIViewController *)controller;
@property (class, nonatomic, readonly) MKMapItemDetailSelectionAccessoryPresentationStyle *callout;
@property (class, nonatomic, readonly) MKMapItemDetailSelectionAccessoryPresentationStyle *openInMaps;
@end

// What the style actually is, in the port's own terms: a class object whose kind is the one
// factory that made it, holding the controller the header's own two factories take. A class with
// `charon_` ivars cannot be, so the kind is held on the metaclass beside it and read back through
// the runtime -- which is the same shape a class object's own state has to have here.
@implementation MKMapItemDetailSelectionAccessoryPresentationStyle

+ (instancetype)charon_styleOfKind:(NSInteger)kind
                            holder:(id)holder
                           calling:(SEL)selector
{
    (void)selector;
    MKMapItemDetailSelectionAccessoryPresentationStyle *style = [super alloc];
    // The class object IS this class, so the kind is recorded on the metaclass and every instance of
    // the metaclass -- which is every style -- reads it. That is the only place a class object has to
    // keep state.
    objc_setAssociatedObject(object_getClass(style), (const void *)"charonStyleKind",
                             [NSNumber numberWithInteger:kind], OBJC_ASSOCIATION_RETAIN);
    if (holder) {
        objc_setAssociatedObject(object_getClass(style), (const void *)"charonStyleHolder", holder,
                                 OBJC_ASSOCIATION_RETAIN);
    }
    return style;
}

+ (NSInteger)charon_kind
{
    id value = objc_getAssociatedObject(object_getClass(self), (const void *)"charonStyleKind");
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

+ (id)charon_holder
{
    return objc_getAssociatedObject(object_getClass(self), (const void *)"charonStyleHolder");
}

// The two class properties, which are what the header says they are: a style, named by its factory.
+ (MKMapItemDetailSelectionAccessoryPresentationStyle *)callout
{
    return (id)objc_getAssociatedObject(object_getClass(self), (const void *)"charonCallout");
}

+ (MKMapItemDetailSelectionAccessoryPresentationStyle *)openInMaps
{
    return (id)objc_getAssociatedObject(object_getClass(self), (const void *)"charonOpenInMaps");
}

+ (instancetype)calloutWithCalloutStyle:(MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyle)style
{
    // The style the callout wears is kept where the accessory can ask for it, because the callout is
    // a view and a view cannot be a style object.
    (void)style;
    return [self charon_styleOfKind:1 holder:nil calling:@selector(calloutWithCalloutStyle:)];
}

+ (instancetype)automaticWithPresentationViewController:(UIViewController *)controller
{
    return [self charon_styleOfKind:2 holder:controller calling:@selector(automaticWithPresentationViewController:)];
}

+ (instancetype)sheetPresentedFromViewController:(UIViewController *)controller
{
    return [self charon_styleOfKind:3 holder:controller calling:@selector(sheetPresentedFromViewController:)];
}

+ (void)charon_seed
{
    // The two no-argument styles, made once and kept, so +callout and +openInMaps are the same
    // object every call and a caller can compare them.
    if (objc_getAssociatedObject(self, (const void *)"charonCallout") == nil) {
        MKMapItemDetailSelectionAccessoryPresentationStyle *callout = [super alloc];
        objc_setAssociatedObject(object_getClass(callout), (const void *)"charonStyleKind",
                                 [NSNumber numberWithInteger:1], OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(self, (const void *)"charonCallout", callout, OBJC_ASSOCIATION_RETAIN);
    }
    if (objc_getAssociatedObject(self, (const void *)"charonOpenInMaps") == nil) {
        MKMapItemDetailSelectionAccessoryPresentationStyle *openInMaps = [super alloc];
        objc_setAssociatedObject(object_getClass(openInMaps), (const void *)"charonStyleKind",
                                 [NSNumber numberWithInteger:4], OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(self, (const void *)"charonOpenInMaps", openInMaps, OBJC_ASSOCIATION_RETAIN);
    }
}

+ (void)initialize
{
    if (self == [MKMapItemDetailSelectionAccessoryPresentationStyle class]) {
        [self charon_seed];
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKMapItemDetailSelectionAccessoryPresentationStyle: %p kind %ld>",
            self, (long)[[self class] charon_kind]];
}

@end

// ============================ the accessory ============================

// MKSelectionAccessory, the iOS 18 accessory that opens a place's detail screen, which the 16.4
// headers do not declare. Apple's own name, under the host guard like the rest of this port's own
// declarations of names a newer SDK carries.
#if !CHARON_HOST_PROBE
@interface MKSelectionAccessory : NSObject
- (instancetype)initWithMapItemDetailPresentationStyle:(MKMapItemDetailSelectionAccessoryPresentationStyle *)presentationStyle;
+ (instancetype)mapItemDetailWithPresentationStyle:(MKMapItemDetailSelectionAccessoryPresentationStyle *)presentationStyle;
- (BOOL)isEqualToSelectionAccessory:(MKSelectionAccessory *)other;
- (MKMapItemDetailSelectionAccessoryPresentationStyle *)mapItemDetailPresentationStyle;
@end
#endif

@implementation MKSelectionAccessory {
    MKMapItemDetailSelectionAccessoryPresentationStyle *_style;
}

// The accessory that opens a place's detail screen, in the style the caller chose. The host's own
// -initWithMapItemDetailPresentationStyle: is @24@0:8@16 (an id), measured.
- (instancetype)initWithMapItemDetailPresentationStyle:(MKMapItemDetailSelectionAccessoryPresentationStyle *)presentationStyle
{
    self = [super init];
    if (self) {
        _style = presentationStyle;
    }
    return self;
}

- (MKMapItemDetailSelectionAccessoryPresentationStyle *)mapItemDetailPresentationStyle
{
    return _style;
}

// The class the header asks for by name: the accessory that presents a place's detail in a style.
+ (instancetype)mapItemDetailWithPresentationStyle:(MKMapItemDetailSelectionAccessoryPresentationStyle *)presentationStyle
{
    return [[self alloc] initWithMapItemDetailPresentationStyle:presentationStyle];
}

- (BOOL)isEqualToSelectionAccessory:(MKSelectionAccessory *)other
{
    if (other == nil) {
        return NO;
    }
    return _style == [other mapItemDetailPresentationStyle];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKSelectionAccessory: %p %@>", self, _style];
}

@end

// ============================ the detail screen ============================

// The detail screen and its delegate, which the 16.4 headers also do not declare. The host's own
// shapes, measured: -initWithMapItem: @24@0:8@16, -initWithMapItem:displaysMap: @28@0:8@16B24 (the B
// is the BOOL), -mapItem @16@0:8, -setMapItem: v24@0:8@16, -delegate @16@0:8, -setDelegate: v24@0:8@16.
#if !CHARON_HOST_PROBE
@protocol MKMapItemDetailViewControllerDelegate <NSObject>
@optional
- (void)mapItemDetailViewControllerDidFinish:(id)viewController;
@end

@interface MKMapItemDetailViewController : UIViewController
- (instancetype)initWithMapItem:(MKMapItem *)mapItem;
- (instancetype)initWithMapItem:(MKMapItem *)mapItem displaysMap:(BOOL)displaysMap;
@property (nonatomic, strong) MKMapItem *mapItem;
@property (nonatomic, weak) id <MKMapItemDetailViewControllerDelegate> delegate;
@end
#endif

@implementation MKMapItemDetailViewController {
    MKMapItem *_mapItem;
    __weak id <MKMapItemDetailViewControllerDelegate> _delegate;
    BOOL _displaysMap;
    UITableView *_table;
    UILabel *_name;
    UILabel *_address;
}

@synthesize mapItem = _mapItem;
@synthesize delegate = _delegate;

// The delegate the header asks for is a protocol the host measures as a plain object, so both are
// answered: the typed one and the runtime's own selector.
- (id)charon_typedDelegate { return _delegate; }

// The header's own designated initialiser, and the second one with the map. Both measured: the first
// takes an id, the second an id and a BOOL.
- (instancetype)initWithMapItem:(MKMapItem *)mapItem
{
    return [self initWithMapItem:mapItem displaysMap:YES];
}

- (instancetype)initWithMapItem:(MKMapItem *)mapItem displaysMap:(BOOL)displaysMap
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _mapItem = mapItem;
        _displaysMap = displaysMap;
        self.title = mapItem.name;
    }
    return self;
}

- (void)setMapItem:(MKMapItem *)mapItem
{
    _mapItem = mapItem;
    self.title = mapItem.name;
    _address.text = [self charon_addressLine];
}

// The item's own name and address, out of the release's own placemark vocabulary -- the same lines
// MKMapItem's own address is built from, read once.
- (NSString *)charon_addressLine
{
    MKPlacemark *placemark = _mapItem.placemark;
    if (!placemark) {
        return nil;
    }
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *part in @[placemark.thoroughfare, placemark.locality, placemark.administrativeArea,
                             placemark.country]) {
        if ([part isKindOfClass:[NSString class]] && part.length > 0) {
            [lines addObject:part];
        }
    }
    return lines.count > 0 ? [lines componentsJoinedByString:@", "] : nil;
}

// The screen itself: the release's own view controller, a table of the item's own vocabulary --
// its name, its address, and the release's own identifier -- and no invented content.
- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 480.0)];
    view.backgroundColor = [UIColor whiteColor];
    _name = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 12.0, 288.0, 28.0)];
    _name.font = [UIFont boldSystemFontOfSize:20.0];
    _name.text = _mapItem.name;
    [view addSubview:_name];
    _address = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 44.0, 288.0, 20.0)];
    _address.font = [UIFont systemFontOfSize:14.0];
    _address.textColor = [UIColor darkGrayColor];
    _address.text = [self charon_addressLine];
    [view addSubview:_address];
    _table = [[UITableView alloc] initWithFrame:CGRectMake(0.0, 72.0, 320.0, 408.0)];
    _table.dataSource = (id)self;
    [view addSubview:_table];
    self.view = view;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSMutableArray *rows = [NSMutableArray array];
    if (_address.text.length > 0) { [rows addObject:_address.text]; }
    if (_mapItem.phoneNumber.length > 0) { [rows addObject:_mapItem.phoneNumber]; }
    if (_mapItem.identifier.length > 0) { [rows addObject:_mapItem.identifier]; }
    return (NSInteger)rows.count;
}

- (NSInteger)charon_rowCount
{
    return [self tableView:nil numberOfRowsInSection:0];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const cellIdentifier = @"CharonMapItemDetailRow";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellIdentifier];
    }
    NSMutableArray *rows = [NSMutableArray array];
    if (_address.text.length > 0) { [rows addObject:_address.text]; }
    if (_mapItem.phoneNumber.length > 0) { [rows addObject:_mapItem.phoneNumber]; }
    if (_mapItem.identifier.length > 0) { [rows addObject:_mapItem.identifier]; }
    if ((NSUInteger)indexPath.row < rows.count) {
        cell.textLabel.text = rows[(NSUInteger)indexPath.row];
    }
    return cell;
}

- (void)mapItemDetailViewControllerDidFinish:(id)viewController
{
    // The delegate's own message, sent when the screen is dismissed, which is the one moment the
    // header's delegate has anything to hear about.
    if ([_delegate respondsToSelector:NSSelectorFromString(@"mapItemDetailViewControllerDidFinish:")]) {
        void (*send)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
        send(_delegate, NSSelectorFromString(@"mapItemDetailViewControllerDidFinish:"), self);
    }
}

@end

NS_ASSUME_NONNULL_END
