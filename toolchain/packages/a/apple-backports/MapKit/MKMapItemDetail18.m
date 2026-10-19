#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "CharonMapKit.h"

@interface MKMapItem (CharonDetailReads)
- (nullable NSString *)identifier;
- (nullable MKAddress *)address;
@end

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(long long, MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyle) {
    MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyleSmall = 0,
    MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyleMedium = 1,
    MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyleLarge = 2,
};

@interface MKMapItemDetailSelectionAccessoryPresentationStyle : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)calloutWithCalloutStyle:(MKMapItemDetailSelectionAccessoryPresentationStyleCalloutStyle)style;
+ (instancetype)automaticWithPresentationViewController:(UIViewController *)controller;
+ (instancetype)sheetPresentedFromViewController:(UIViewController *)controller;
@property (class, nonatomic, readonly) MKMapItemDetailSelectionAccessoryPresentationStyle *callout;
@property (class, nonatomic, readonly) MKMapItemDetailSelectionAccessoryPresentationStyle *openInMaps;
@end

@implementation MKMapItemDetailSelectionAccessoryPresentationStyle

+ (instancetype)charon_styleOfKind:(NSInteger)kind
                            holder:(id)holder
                           calling:(SEL)selector
{
    (void)selector;
    MKMapItemDetailSelectionAccessoryPresentationStyle *style = [super alloc];
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

- (id)charon_typedDelegate { return _delegate; }

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
    if ([_delegate respondsToSelector:NSSelectorFromString(@"mapItemDetailViewControllerDidFinish:")]) {
        void (*send)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
        send(_delegate, NSSelectorFromString(@"mapItemDetailViewControllerDidFinish:"), self);
    }
}

@end

NS_ASSUME_NONNULL_END
