#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "RevenantMapKit.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MKMapItemDetailSelectionAccessoryPresentationStyle

+ (instancetype)revenant_styleOfKind:(NSInteger)kind
                            holder:(id)holder
                           calling:(SEL)selector
{
    (void)selector;
    MKMapItemDetailSelectionAccessoryPresentationStyle *style = [super alloc];
    objc_setAssociatedObject(object_getClass(style), (const void *)"revenantStyleKind",
                             [NSNumber numberWithInteger:kind], OBJC_ASSOCIATION_RETAIN);
    if (holder) {
        objc_setAssociatedObject(object_getClass(style), (const void *)"revenantStyleHolder", holder,
                                 OBJC_ASSOCIATION_RETAIN);
    }
    return style;
}

+ (NSInteger)revenant_kind
{
    id value = objc_getAssociatedObject(object_getClass(self), (const void *)"revenantStyleKind");
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

+ (id)revenant_holder
{
    return objc_getAssociatedObject(object_getClass(self), (const void *)"revenantStyleHolder");
}

+ (MKMapItemDetailSelectionAccessoryPresentationStyle *)callout
{
    return (id)objc_getAssociatedObject(object_getClass(self), (const void *)"revenantCallout");
}

+ (MKMapItemDetailSelectionAccessoryPresentationStyle *)openInMaps
{
    return (id)objc_getAssociatedObject(object_getClass(self), (const void *)"revenantOpenInMaps");
}

+ (instancetype)calloutWithCalloutStyle:(MKMapItemDetailSelectionAccessoryCalloutStyle)style
{
    (void)style;
    return [self revenant_styleOfKind:1 holder:nil calling:@selector(calloutWithCalloutStyle:)];
}

+ (MKMapItemDetailSelectionAccessoryPresentationStyle *)automaticWithPresentationViewController:(nullable UIViewController *)controller
{
    return [self revenant_styleOfKind:2 holder:controller calling:@selector(automaticWithPresentationViewController:)];
}

+ (instancetype)sheetPresentedFromViewController:(UIViewController *)controller
{
    return [self revenant_styleOfKind:3 holder:controller calling:@selector(sheetPresentedFromViewController:)];
}

+ (void)revenant_seed
{
    if (objc_getAssociatedObject(self, (const void *)"revenantCallout") == nil) {
        MKMapItemDetailSelectionAccessoryPresentationStyle *callout = [super alloc];
        objc_setAssociatedObject(object_getClass(callout), (const void *)"revenantStyleKind",
                                 [NSNumber numberWithInteger:1], OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(self, (const void *)"revenantCallout", callout, OBJC_ASSOCIATION_RETAIN);
    }
    if (objc_getAssociatedObject(self, (const void *)"revenantOpenInMaps") == nil) {
        MKMapItemDetailSelectionAccessoryPresentationStyle *openInMaps = [super alloc];
        objc_setAssociatedObject(object_getClass(openInMaps), (const void *)"revenantStyleKind",
                                 [NSNumber numberWithInteger:4], OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(self, (const void *)"revenantOpenInMaps", openInMaps, OBJC_ASSOCIATION_RETAIN);
    }
}

+ (void)initialize
{
    if (self == [MKMapItemDetailSelectionAccessoryPresentationStyle class]) {
        [self revenant_seed];
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKMapItemDetailSelectionAccessoryPresentationStyle: %p kind %ld>",
            self, (long)[[self class] revenant_kind]];
}

@end


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

- (id)revenant_typedDelegate { return _delegate; }

- (instancetype)initWithMapItem:(nullable MKMapItem *)mapItem
{
    return [self initWithMapItem:mapItem displaysMap:YES];
}

- (instancetype)initWithMapItem:(nullable MKMapItem *)mapItem displaysMap:(BOOL)displaysMap
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _mapItem = mapItem;
        _displaysMap = displaysMap;
        self.title = mapItem.name;
    }
    return self;
}

- (void)setMapItem:(nullable MKMapItem *)mapItem
{
    _mapItem = mapItem;
    self.title = mapItem.name;
    _address.text = [self revenant_addressLine];
}

- (NSString *)revenant_addressLine
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
    _address.text = [self revenant_addressLine];
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
    if (_mapItem.identifier.identifierString.length > 0) { [rows addObject:_mapItem.identifier.identifierString]; }
    return (NSInteger)rows.count;
}

- (NSInteger)revenant_rowCount
{
    return [self tableView:nil numberOfRowsInSection:0];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const cellIdentifier = @"RevenantMapItemDetailRow";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellIdentifier];
    }
    NSMutableArray *rows = [NSMutableArray array];
    if (_address.text.length > 0) { [rows addObject:_address.text]; }
    if (_mapItem.phoneNumber.length > 0) { [rows addObject:_mapItem.phoneNumber]; }
    if (_mapItem.identifier.identifierString.length > 0) { [rows addObject:_mapItem.identifier.identifierString]; }
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
