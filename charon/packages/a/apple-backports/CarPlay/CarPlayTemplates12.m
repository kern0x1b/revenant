// CarPlay's templates, on iOS 6, as real in-app view controllers, in the shapes the SDK declares.
//
// There is no CarPlay class of any name in this release (apple.objc.inventory against the armv7 cache
// of 6.1.3), and there is no car: a CarPlay scene is a connection to a head unit, and without a car
// there is no scene, which is Apple's own behaviour without a car. So this file is the half of CarPlay
// that draws, and the half that needs the car is `CPTemplateApplicationScene` and its two siblings in
// the registry as `absent`, one reason each.
//
// What is here, and how it draws:
//
//   CPWindow            a window the application owns, which is what a car's window is here;
//   CPTemplate          a screen's own values, and the tab it is reached by;
//   CPBarButton,        NSObject subclasses, not views, exactly as the SDK declares them, so each
//   CPGridButton,       is DRAWN BY THE TEMPLATE THAT HOLDS IT: a bar button in a navigation bar,
//   CPMapButton         a grid button in a collection view cell, a map button over the map;
//   CPListItem          a row, conforming to CPSelectableListItem, whose own handler is called when
//                       the row is chosen;
//   CPListTemplate      a UITableViewController over the template's own sections and rows;
//   CPGridTemplate      a UICollectionViewController over the template's own buttons;
//   CPMapTemplate       the release's own MKMapView, with this port's own renderers on it;
//   CPTravelEstimates   the port's own NSMeasurement and NSUnitLength, which libFoundationBackports
//                       carries and the release has not (both registered implemented, minimum 6.0);
//   CPInterfaceController  the object that owns the window, pushes and pops, and tells its delegate.
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <math.h>
#import "CharonCarPlayTemplate.h"
#import "CharonCarPlay174.h"

// The header's own rect of a given aspect ratio inside another, which UIKit does not export and this
// file needs three times to draw a button's own image at its own shape. Charon's own, so no API.
static CGRect CharonAspectFit(CGSize size, CGRect rect)
{
    if (size.width <= 0.0 || size.height <= 0.0) {
        return rect;
    }
    CGFloat scale = MIN(CGRectGetWidth(rect) / size.width, CGRectGetHeight(rect) / size.height);
    CGSize fitted = CGSizeMake(size.width * scale, size.height * scale);
    return CGRectMake(CGRectGetMidX(rect) - fitted.width / 2.0, CGRectGetMidY(rect) - fitted.height / 2.0,
                       fitted.width, fitted.height);
}

// ============================ the window ============================

@implementation CPWindow {
    __weak id _templateApplicationScene;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
    }
    return self;
}

// The scene this window belongs to. There is no car, so there is no scene: the getter is nil, which
// is what the header's own weak property is, and the registry carries the scene classes as absent at
// the seam with the reason.
- (id)templateApplicationScene
{
    return _templateApplicationScene;
}

- (void)setTemplateApplicationScene:(id)templateApplicationScene
{
    _templateApplicationScene = templateApplicationScene;
}

@end

// ============================ the template ============================

// CPTemplate has NO title, and that is measured rather than assumed: the 26.2 SDK's own
// CPTemplate.h mentions "the template's title" in a note and declares no such property, and the
// templates that do have one -- CPListTemplate, CPGridTemplate, CPMapTemplate -- declare it on
// themselves. So a name no header declares is not carried here (rule R4); the tab's own name is this
// template's tabTitle, which is the header's own.

@implementation CPTemplate {
    id _userInfo;
    NSString *_tabTitle;
    UIImage *_tabImage;
    UITabBarSystemItem _tabSystemItem;
    BOOL _showsTabBadge;
    __weak CPInterfaceController *_charonController;
}

@synthesize userInfo = _userInfo;
@synthesize tabTitle = _tabTitle;
@synthesize tabImage = _tabImage;
@synthesize tabSystemItem = _tabSystemItem;
@synthesize showsTabBadge = _showsTabBadge;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _tabSystemItem = UITabBarSystemItemMore;
    }
    return self;
}

// The image the tab is drawn with: the caller's own, and otherwise the system item's own mark drawn
// here, so a template that names a system item is reached by something a bar can draw.
- (UIImage *)charon_tabMark
{
    if (_tabImage) {
        return _tabImage;
    }
    if (_tabSystemItem == UITabBarSystemItemMore) {
        return nil;
    }
    NSString *name = [CPTemplate charon_nameForSystemItem:_tabSystemItem];
    CGSize size = CGSizeMake(25.0, 25.0);
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:17.0],
                                 NSForegroundColorAttributeName: [UIColor whiteColor]};
    CGSize text = [name sizeWithAttributes:attributes];
    [name drawAtPoint:CGPointMake((size.width - text.width) / 2.0, (size.height - text.height) / 2.0)
       withAttributes:attributes];
    UIImage *drawn = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return drawn;
}

// The header's own tab system items, by the name each of them carries. Charon's own, so no API.
+ (NSString *)charon_nameForSystemItem:(UITabBarSystemItem)item
{
    switch (item) {
        case UITabBarSystemItemFavorites: return @"Favorites";
        case UITabBarSystemItemFeatured: return @"Featured";
        case UITabBarSystemItemTopRated: return @"Top Rated";
        case UITabBarSystemItemRecents: return @"Recents";
        case UITabBarSystemItemContacts: return @"Contacts";
        case UITabBarSystemItemHistory: return @"History";
        case UITabBarSystemItemBookmarks: return @"Bookmarks";
        case UITabBarSystemItemSearch: return @"Search";
        case UITabBarSystemItemDownloads: return @"Downloads";
        case UITabBarSystemItemMostRecent: return @"Most Recent";
        case UITabBarSystemItemMostViewed: return @"Most Viewed";
        default: return @"";
    }
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_tabTitle forKey:@"CPTabTitle"];
    [coder encodeInteger:(NSInteger)_tabSystemItem forKey:@"CPTabSystemItem"];
    [coder encodeBool:_showsTabBadge forKey:@"CPShowsTabBadge"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _tabTitle = [coder decodeObjectForKey:@"CPTabTitle"];
        _tabSystemItem = (UITabBarSystemItem)[coder decodeIntegerForKey:@"CPTabSystemItem"];
        _showsTabBadge = [coder decodeBoolForKey:@"CPShowsTabBadge"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// The view controller this template draws itself in, which the interface controller asks for when it
// pushes it. A template with no view controller of its own has nothing to show, and the interface
// controller says so rather than pushing an empty screen.
- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    return nil;
}

@end

// ============================ the bar button ============================

@implementation CPBarButton {
    UIImage *_image;
    NSString *_title;
    BOOL _enabled;
    CPBarButtonType _buttonType;
    CPBarButtonStyle _buttonStyle;
    CPBarButtonHandler _handler;
}

@synthesize image = _image;
@synthesize title = _title;
@synthesize buttonType = _buttonType;
@synthesize buttonStyle = _buttonStyle;

- (instancetype)initWithImage:(UIImage *)image handler:(CPBarButtonHandler)handler
{
    self = [super init];
    if (self) {
        _image = image;
        _handler = [handler copy];
        _enabled = YES;
        _buttonStyle = CPBarButtonStyleNone;
        _buttonType = CPBarButtonTypeImage;
    }
    return self;
}

- (instancetype)initWithTitle:(NSString *)title handler:(CPBarButtonHandler)handler
{
    self = [super init];
    if (self) {
        _title = [title copy];
        _handler = [handler copy];
        _enabled = YES;
        _buttonStyle = CPBarButtonStyleNone;
        _buttonType = CPBarButtonTypeImage;
    }
    return self;
}

- (instancetype)initWithType:(CPBarButtonType)type handler:(CPBarButtonHandler)handler
{
    self = [super init];
    if (self) {
        _buttonType = type;
        _handler = [handler copy];
        _enabled = YES;
        _buttonStyle = CPBarButtonStyleNone;
    }
    return self;
}

+ (instancetype)buttonWithTitle:(NSString *)title handler:(CPBarButtonHandler)handler
{
    return [[self alloc] initWithTitle:title handler:handler];
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_title forKey:@"CPBarButtonTitle"];
    [coder encodeInteger:(NSInteger)_buttonType forKey:@"CPBarButtonType"];
    [coder encodeInteger:(NSInteger)_buttonStyle forKey:@"CPBarButtonStyle"];
    [coder encodeBool:_enabled forKey:@"CPBarButtonEnabled"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _title = [coder decodeObjectForKey:@"CPBarButtonTitle"];
        _buttonType = (CPBarButtonType)[coder decodeIntegerForKey:@"CPBarButtonType"];
        _buttonStyle = (CPBarButtonStyle)[coder decodeIntegerForKey:@"CPBarButtonStyle"];
        _enabled = [coder decodeBoolForKey:@"CPBarButtonEnabled"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// The button, DRAWN. A CPBarButton is an NSObject and not a view, so the drawing is here and the
// template that holds it puts this into its own bar. The handler is a program's own block, called
// when the drawn mark is tapped. Charon's own, so it carries no API.
- (void)charon_drawInRect:(CGRect)rect alpha:(CGFloat)alpha
{
    if (rect.size.width <= 0.0 || rect.size.height <= 0.0) {
        return;
    }
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }
    CGContextSaveGState(context);
    CGContextSetAlpha(context, (CGFloat)alpha);
    if (_image) {
        CGRect box = CharonAspectFit(_image.size, rect);
        [_image drawInRect:box];
    } else if (_title.length > 0) {
        NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                                     NSForegroundColorAttributeName: [UIColor whiteColor]};
        CGSize text = [_title sizeWithAttributes:attributes];
        [_title drawAtPoint:CGPointMake(CGRectGetMinX(rect) + (CGRectGetWidth(rect) - text.width) / 2.0,
                                         CGRectGetMinY(rect) + (CGRectGetHeight(rect) - text.height) / 2.0)
            withAttributes:attributes];
    } else {
        // A button with no image and no title and a type is the type's own mark: a square with a
        // chevron, drawn here rather than left blank.
        UIBezierPath *mark = [UIBezierPath bezierPath];
        CGFloat inset = 8.0;
        [mark moveToPoint:CGPointMake(CGRectGetMinX(rect) + inset, CGRectGetMinY(rect) + inset)];
        [mark addLineToPoint:CGPointMake(CGRectGetMaxX(rect) - inset, CGRectGetMinY(rect) + inset)];
        [mark addLineToPoint:CGPointMake(CGRectGetMaxX(rect) - inset, CGRectGetMaxY(rect) - inset)];
        [mark addLineToPoint:CGPointMake(CGRectGetMinX(rect) + inset, CGRectGetMaxY(rect) - inset)];
        [mark closePath];
        [[UIColor colorWithWhite:1.0 alpha:0.2] setFill];
        [mark fill];
        [[UIColor whiteColor] setStroke];
        [mark stroke];
    }
    CGContextRestoreGState(context);
}

- (void)charon_tap
{
    if (_handler) {
        _handler(self);
    }
}

@end

// ============================ the grid button and the map button ============================

@implementation CPGridButton {
    NSArray<NSString *> *_titleVariants;
    UIImage *_image;
    BOOL _enabled;
    void (^_handler)(CPGridButton *);
    // The 26.0 members' storage, reached from CarPlayGrid260.m through the charon_ accessors below. See
    // the comment on those accessors for why it is here and not there.
    CPMessageGridItemConfiguration *_charon_messageConfiguration;
}

@synthesize titleVariants = _titleVariants;
@synthesize image = _image;

- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants
                                 image:(UIImage *)image
                               handler:(void (^)(CPGridButton *))handler
{
    self = [super init];
    if (self) {
        _titleVariants = [titleVariants copy] ?: @[];
        _image = image;
        _handler = [handler copy];
        _enabled = YES;
    }
    return self;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

// The 26.0 object's storage, reached from CarPlayGrid260.m. A category cannot add an ivar and the class's
// @implementation is this file, so the value lives here behind Charon-prefixed accessors - the same shape
// CarPlayNavigationSession12.m uses for _turnCardColor. Every name is Charon-prefixed, so none of it is
// API and none of it appears in this object's exports: this file is 12.0 and stays 12.0, and the 26.0
// selectors live in their own object.
//
// The 26.0 `-updateImage:` writes the image, and the class's own drawing is what reads it, so the
// image stays where the class's own @implementation keeps it.
- (void)charon_setImage:(UIImage *)image
{
    _image = image;
}

// The message configuration is held as given: CPGridButton.h:71 declares it `readonly, nullable` with no
// copy attribute, so a nil in is a nil out and nothing is duplicated.
- (CPMessageGridItemConfiguration *)charon_messageConfiguration
{
    return _charon_messageConfiguration;
}

- (void)charon_setMessageConfiguration:(CPMessageGridItemConfiguration *)messageConfiguration
{
    _charon_messageConfiguration = messageConfiguration;
}

- (void)charon_setTitleVariants:(NSArray<NSString *> *)titleVariants
{
    // CPGridButton.h:88 declares titleVariants `readonly, copy`, so the copy happens here and a later
    // change to the caller's array does not change the button.
    _titleVariants = [titleVariants copy] ?: @[];
}

// The button, drawn by the grid template that holds it: its image above the first of its own title
// variants, which is the variant this port has a name for. Charon's own, so it carries no API.
- (void)charon_drawInRect:(CGRect)rect
{
    if (CGRectIsEmpty(rect) || !_enabled) {
        return;
    }
    CGFloat imageHeight = MIN(CGRectGetWidth(rect) * 0.6, CGRectGetHeight(rect) * 0.6);
    if (_image) {
        CGRect box = CharonAspectFit(_image.size, rect);
        box.size.height = MIN(box.size.height, imageHeight);
        box.origin = CGPointMake(CGRectGetMidX(rect) - box.size.width / 2.0, CGRectGetMinY(rect));
        [_image drawInRect:box];
    }
    NSString *title = _titleVariants.firstObject;
    if (title.length == 0) {
        return;
    }
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:15.0],
                                 NSForegroundColorAttributeName: [UIColor whiteColor]};
    CGSize text = [title sizeWithAttributes:attributes];
    [title drawAtPoint:CGPointMake(CGRectGetMidX(rect) - text.width / 2.0,
                                   CGRectGetMaxY(rect) - text.height)
       withAttributes:attributes];
}

- (void)charon_tap
{
    if (_handler) {
        _handler(self);
    }
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_titleVariants forKey:@"CPGridButtonTitleVariants"];
    [coder encodeBool:_enabled forKey:@"CPGridButtonEnabled"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _titleVariants = [coder decodeObjectForKey:@"CPGridButtonTitleVariants"] ?: @[];
        _enabled = [coder decodeBoolForKey:@"CPGridButtonEnabled"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

@implementation CPMapButton {
    BOOL _enabled;
    BOOL _hidden;
    UIImage *_image;
    UIImage *_focusedImage;
    void (^_handler)(CPMapButton *);
}

@synthesize image = _image;
@synthesize focusedImage = _focusedImage;

- (instancetype)initWithHandler:(void (^)(CPMapButton *))handler
{
    self = [super init];
    if (self) {
        _handler = [handler copy];
        _enabled = YES;
    }
    return self;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

- (BOOL)isHidden
{
    return _hidden;
}

- (void)setHidden:(BOOL)hidden
{
    _hidden = hidden;
}

// The button, drawn by the map template over its map, inside the window's own map button safe area.
- (void)charon_drawInRect:(CGRect)rect
{
    if (_hidden || !_enabled || CGRectIsEmpty(rect)) {
        return;
    }
    UIBezierPath *plate = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:8.0];
    [[UIColor colorWithWhite:0.0 alpha:0.6] setFill];
    [plate fill];
    UIImage *mark = _image;
    if (mark) {
        CGRect box = CharonAspectFit(mark.size, CGRectInset(rect, 8.0, 8.0));
        [mark drawInRect:box];
    }
}

- (void)charon_tap
{
    if (_handler) {
        _handler(self);
    }
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_enabled forKey:@"CPMapButtonEnabled"];
    [coder encodeBool:_hidden forKey:@"CPMapButtonHidden"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _enabled = [coder decodeBoolForKey:@"CPMapButtonEnabled"];
        _hidden = [coder decodeBoolForKey:@"CPMapButtonHidden"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

// ============================ the maneuver and the estimates ============================

@implementation CPTravelEstimates {
    NSMeasurement<NSUnitLength *> *_distanceRemaining;
    NSTimeInterval _timeRemaining;
    // The 17.4 member's storage, reached from CarPlayTravelEstimates174.m through the charon_ accessors
    // below. See the comment on those accessors for why it is here and not there.
    NSMeasurement<NSUnitLength *> *_charon_distanceRemainingToDisplay;
}

@synthesize distanceRemaining = _distanceRemaining;
@synthesize timeRemaining = _timeRemaining;

// The header's own initialiser, and the distance is the port's own NSMeasurement of a distance in a
// length unit: libFoundationBackports carries NSUnitLength and NSMeasurement (both registered
// implemented, minimum 6.0) precisely because the release has neither, and this is the member that
// needs them.
- (instancetype)initWithDistanceRemaining:(NSMeasurement<NSUnitLength *> *)distanceRemaining
                            timeRemaining:(NSTimeInterval)timeRemaining
{
    self = [super init];
    if (self) {
        _distanceRemaining = distanceRemaining;
        _timeRemaining = timeRemaining;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:[_distanceRemaining doubleValue] forKey:@"CPTravelEstimatesDistance"];
    [coder encodeDouble:_timeRemaining forKey:@"CPTravelEstimatesTime"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _distanceRemaining = [[NSMeasurement alloc] initWithDoubleValue:[coder decodeDoubleForKey:@"CPTravelEstimatesDistance"]
                                                                   unit:[NSUnitLength meters]];
        _timeRemaining = [coder decodeDoubleForKey:@"CPTravelEstimatesTime"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CPTravelEstimates: %p %.0f m in %.0f s>", self,
            [_distanceRemaining doubleValue], _timeRemaining];
}

// The 17.4 member's storage, reached from CarPlayTravelEstimates174.m. A category cannot add an ivar and
// the class's @implementation is this file, so the value lives here behind a Charon-prefixed accessor -
// the same shape CarPlayNavigationSession12.m uses for _turnCardColor. The name is Charon-prefixed, so
// none of it is API and none of it appears in this object's exports: this file is 12.0 and stays 12.0,
// and the 17.4 selectors live in their own object.
- (NSMeasurement<NSUnitLength *> *)charon_distanceRemainingToDisplay
{
    return _charon_distanceRemainingToDisplay;
}

- (void)charon_setDistanceRemainingToDisplay:(NSMeasurement<NSUnitLength *> *)distance
{
    _charon_distanceRemainingToDisplay = distance;
}

@end

@implementation CPManeuver {
    NSArray<NSString *> *_instructionVariants;
    NSArray<NSAttributedString *> *_attributedInstructionVariants;
    NSArray<NSString *> *_dashboardInstructionVariants;
    NSArray<NSAttributedString *> *_dashboardAttributedInstructionVariants;
    NSArray<NSString *> *_notificationInstructionVariants;
    NSArray<NSAttributedString *> *_notificationAttributedInstructionVariants;
    UIImage *_symbolImage;
    UIImage *_junctionImage;
    UIImage *_dashboardSymbolImage;
    UIImage *_dashboardJunctionImage;
    UIImage *_notificationSymbolImage;
    CPImageSet *_symbolSet;
    UIColor *_cardBackgroundColor;
    CPTravelEstimates *_initialTravelEstimates;
    id _userInfo;
    // The 17.4 members' storage, reached from CarPlayManeuver174.m through the charon_ accessors below.
    // See the comment on those accessors for why it is here and not there.
    CPManeuverType _charon_maneuverType;
    CPTrafficSide _charon_trafficSide;
    CPJunctionType _charon_junctionType;
    NSMeasurement<NSUnitAngle *> *_charon_junctionExitAngle;
    NSSet<NSMeasurement<NSUnitAngle *> *> *_charon_junctionElementAngles;
    CPLaneGuidance *_charon_linkedLaneGuidance;
    NSArray<NSString *> *_charon_roadFollowingManeuverVariants;
    NSString *_charon_highwayExitLabel;
}

@synthesize instructionVariants = _instructionVariants;
@synthesize attributedInstructionVariants = _attributedInstructionVariants;
@synthesize dashboardInstructionVariants = _dashboardInstructionVariants;
@synthesize dashboardAttributedInstructionVariants = _dashboardAttributedInstructionVariants;
@synthesize notificationInstructionVariants = _notificationInstructionVariants;
@synthesize notificationAttributedInstructionVariants = _notificationAttributedInstructionVariants;
@synthesize symbolImage = _symbolImage;
@synthesize junctionImage = _junctionImage;
@synthesize dashboardSymbolImage = _dashboardSymbolImage;
@synthesize dashboardJunctionImage = _dashboardJunctionImage;
@synthesize notificationSymbolImage = _notificationSymbolImage;
@synthesize symbolSet = _symbolSet;
@synthesize cardBackgroundColor = _cardBackgroundColor;
@synthesize initialTravelEstimates = _initialTravelEstimates;
@synthesize userInfo = _userInfo;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _instructionVariants = @[];
        _attributedInstructionVariants = @[];
        _dashboardInstructionVariants = @[];
        _dashboardAttributedInstructionVariants = @[];
        _notificationInstructionVariants = @[];
        _notificationAttributedInstructionVariants = @[];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CPManeuver *copy = [[[self class] allocWithZone:zone] init];
    copy->_instructionVariants = [_instructionVariants copy];
    copy->_attributedInstructionVariants = [_attributedInstructionVariants copy];
    copy->_symbolImage = _symbolImage;
    copy->_junctionImage = _junctionImage;
    copy->_initialTravelEstimates = _initialTravelEstimates;
    copy->_userInfo = _userInfo;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_instructionVariants forKey:@"CPManeuverInstructionVariants"];
    [coder encodeObject:_symbolImage forKey:@"CPManeuverSymbolImage"];
    [coder encodeObject:_junctionImage forKey:@"CPManeuverJunctionImage"];
    [coder encodeObject:_userInfo forKey:@"CPManeuverUserInfo"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        _instructionVariants = [coder decodeObjectForKey:@"CPManeuverInstructionVariants"] ?: @[];
        _symbolImage = [coder decodeObjectForKey:@"CPManeuverSymbolImage"];
        _junctionImage = [coder decodeObjectForKey:@"CPManeuverJunctionImage"];
        _userInfo = [coder decodeObjectForKey:@"CPManeuverUserInfo"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// The 17.4 members of CPManeuver, kept here and reached from CarPlayManeuver174.m. A category cannot
// add an ivar and the class's @implementation is this file, so the values those eight properties hold
// live here behind Charon-prefixed accessors - the same shape CarPlayNavigationSession12.m already uses
// for _turnCardColor through -charon_pauseWithReason:description:turnCardColor: and the one
// CarPlayTemplatesView12.m uses for CPListTemplate's 18.4 and 26.0 members. Every name is
// Charon-prefixed, so none of it is API and none of it appears in this object's exports: this file is
// 12.0 and stays 12.0, and the 17.4 selectors live in their own object.
//
// The defaults are the zero of each type, which is what a fresh -init leaves behind and what the
// headers' own numbering makes: CPManeuverTypeNoTurn = 0 and CPJunctionTypeIntersection = 0 and
// CPTrafficSideRight = 0 (CharonCarPlay174.h, from CPManeuver.h:14-79). So a maneuver with nothing set
// is a maneuver with no turn, at an intersection, with traffic on the right - and nil for the four
// objects, which is what the header's own `nullable, copy` promises.
- (CPManeuverType)charon_maneuverType { return _charon_maneuverType; }
- (void)charon_setManeuverType:(CPManeuverType)type { _charon_maneuverType = type; }

- (CPTrafficSide)charon_trafficSide { return _charon_trafficSide; }
- (void)charon_setTrafficSide:(CPTrafficSide)side { _charon_trafficSide = side; }

- (CPJunctionType)charon_junctionType { return _charon_junctionType; }
- (void)charon_setJunctionType:(CPJunctionType)type { _charon_junctionType = type; }

- (NSMeasurement<NSUnitAngle *> *)charon_junctionExitAngle { return _charon_junctionExitAngle; }
- (void)charon_setJunctionExitAngle:(NSMeasurement<NSUnitAngle *> *)angle
{
    _charon_junctionExitAngle = angle;
}

- (NSSet<NSMeasurement<NSUnitAngle *> *> *)charon_junctionElementAngles
{
    return _charon_junctionElementAngles;
}
- (void)charon_setJunctionElementAngles:(NSSet<NSMeasurement<NSUnitAngle *> *> *)angles
{
    _charon_junctionElementAngles = angles;
}

- (CPLaneGuidance *)charon_linkedLaneGuidance { return _charon_linkedLaneGuidance; }
- (void)charon_setLinkedLaneGuidance:(CPLaneGuidance *)guidance { _charon_linkedLaneGuidance = guidance; }

- (NSArray<NSString *> *)charon_roadFollowingManeuverVariants
{
    return _charon_roadFollowingManeuverVariants;
}
- (void)charon_setRoadFollowingManeuverVariants:(NSArray<NSString *> *)variants
{
    _charon_roadFollowingManeuverVariants = [variants copy];
}

- (NSString *)charon_highwayExitLabel { return _charon_highwayExitLabel; }
- (void)charon_setHighwayExitLabel:(NSString *)label { _charon_highwayExitLabel = [label copy]; }

@end

// ============================ the alert ============================

@implementation CPAlertAction {
    NSString *_title;
    CPAlertActionStyle _style;
    CPAlertActionHandler _handler;
    UIColor *_color;
}

@synthesize title = _title;
@synthesize style = _style;
@synthesize handler = _handler;
@synthesize color = _color;

- (instancetype)initWithTitle:(NSString *)title style:(CPAlertActionStyle)style handler:(CPAlertActionHandler)handler
{
    // CPAlertAction.h:40, the header's own 12.0 initialiser: a title, a display style and the callback
    // the header says is "invoked when the user taps this action". The title is copied, which is the
    // header's own `copy` on the title property at :57, and the handler with it - a block copied under
    // ARC is the same block, so this is the header's `copy` on the handler property at :59 and not a
    // second copy of anything. A nil title becomes the empty string, because the title is nonnull and a
    // nil in would otherwise be stored and answered.
    self = [super init];
    if (self) {
        _title = [title copy] ?: @"";
        _style = style;
        _handler = [handler copy];
    }
    return self;
}

- (instancetype)initWithTitle:(NSString *)title handler:(CPAlertActionHandler)handler style:(CPAlertActionStyle)style color:(UIColor *)color
{
    // The port's own four-value spelling, which the header has no declaration for: it is the header's
    // 12.0 initialiser and its 16.0 colour in one, and the 16.0 half is CarPlayAlertAction160.m's. Kept
    // because it was already here and something may call it; it now says so rather than filling the
    // fields twice.
    self = [self initWithTitle:title style:style handler:handler];
    if (self) {
        [self charon_setColor:color];
    }
    return self;
}

// The 16.0 object's storage, reached from CarPlayAlertAction160.m. It is declared in
// CharonCarPlayTemplate.h, and the name is Charon-prefixed, so none of it is API and none of it appears
// in this object's exports.
- (void)charon_setColor:(UIColor *)color
{
    // CPAlertAction.h:60 declares color `copy, readonly, nullable`, so the copy is what the property's own
    // attribute asks for and a nil in stays nil.
    _color = [color copy];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_title forKey:@"CPAlertActionTitle"];
    [coder encodeInteger:(NSInteger)_style forKey:@"CPAlertActionStyle"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _title = [coder decodeObjectForKey:@"CPAlertActionTitle"];
        _style = (CPAlertActionStyle)[coder decodeIntegerForKey:@"CPAlertActionStyle"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

@implementation CPNavigationAlert {
    NSArray<NSString *> *_titleVariants;
    NSArray<NSString *> *_subtitleVariants;
    CPImageSet *_imageSet;
    UIImage *_image;
    CPAlertAction *_primaryAction;
    CPAlertAction *_secondaryAction;
    NSTimeInterval _duration;
}

@synthesize titleVariants = _titleVariants;
@synthesize subtitleVariants = _subtitleVariants;
@synthesize imageSet = _imageSet;
@synthesize image = _image;
@synthesize primaryAction = _primaryAction;
@synthesize secondaryAction = _secondaryAction;
@synthesize duration = _duration;

- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants
                       subtitleVariants:(NSArray<NSString *> *)subtitleVariants
                             imageSet:(CPImageSet *)imageSet
                               duration:(NSTimeInterval)duration
                         primaryAction:(CPAlertAction *)primaryAction
                       secondaryAction:(CPAlertAction *)secondaryAction
{
    self = [super init];
    if (self) {
        _titleVariants = [titleVariants copy] ?: @[];
        _subtitleVariants = [subtitleVariants copy] ?: @[];
        _imageSet = imageSet;
        _duration = duration;
        _primaryAction = primaryAction;
        _secondaryAction = secondaryAction;
    }
    return self;
}

- (void)updateTitleVariants:(NSArray<NSString *> *)newTitleVariants
           subtitleVariants:(NSArray<NSString *> *)newSubtitleVariants
                     imageSet:(CPImageSet *)newImageSet
                   imageArray:(NSArray<UIImage *> *)newImageArray
                     duration:(NSTimeInterval)newDuration
               primaryAction:(CPAlertAction *)newPrimaryAction
             secondaryAction:(CPAlertAction *)newSecondaryAction
{
    // The header's own update: what the alert now says, which is the map template's own alert and
    // not a copy of it.
    _titleVariants = [newTitleVariants copy] ?: @[];
    _subtitleVariants = [newSubtitleVariants copy] ?: @[];
    _imageSet = newImageSet;
    _image = newImageArray.firstObject;
_duration = newDuration;
        _primaryAction = newPrimaryAction;
        _secondaryAction = newSecondaryAction;
}

// CPNavigationAlert.h:58-63, the header's own 12.0 initialiser with a CPImageSet, deprecated in 13.0 in
// favour of the image overload below it. It is here because the header's own deprecated declaration is
// still a declaration an application may compile against, and the argument order is the header's:
// imageSet, primaryAction, secondaryAction, duration.
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants
                     subtitleVariants:(NSArray<NSString *> *)subtitleVariants
                             imageSet:(CPImageSet *)imageSet
                        primaryAction:(CPAlertAction *)primaryAction
                      secondaryAction:(CPAlertAction *)secondaryAction
                             duration:(NSTimeInterval)duration
{
    // The image set is kept as given and the standalone image stays nil, which is the header's own
    // reading of the deprecation: when an animated image is provided, the header says only the first image of each
    // set is used (CPNavigationAlert.h:46-47), so a set and an image are two ways of saying
    // the same picture and this one says it with the set. The title and subtitle variants are copied and
    // a nil in becomes empty, as the header's own `copy` properties would.
    self = [super init];
    if (self) {
        _titleVariants = [titleVariants copy] ?: @[];
        _subtitleVariants = [subtitleVariants copy] ?: @[];
        _imageSet = imageSet;
        _primaryAction = primaryAction;
        _secondaryAction = secondaryAction;
        _duration = duration;
    }
    return self;
}

// CPNavigationAlert.h:65-70, the header's own 12.0 initialiser with a UIImage - the one the deprecation
// above points at, and the one an application on 13.0 or later writes.
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants
                     subtitleVariants:(NSArray<NSString *> *)subtitleVariants
                                image:(UIImage *)image
                        primaryAction:(CPAlertAction *)primaryAction
                      secondaryAction:(CPAlertAction *)secondaryAction
                             duration:(NSTimeInterval)duration
{
    // The image goes to the class's own -image, which CPNavigationAlert.h:87 declares `copy, readonly,
    // nullable`, and the image set stays nil because this overload does not take one. Animated images
    // are not supported by the header either, and this stores the image as given rather than stepping
    // through its frames.
    self = [super init];
    if (self) {
        _titleVariants = [titleVariants copy] ?: @[];
        _subtitleVariants = [subtitleVariants copy] ?: @[];
        _image = image;
        _primaryAction = primaryAction;
        _secondaryAction = secondaryAction;
        _duration = duration;
    }
    return self;
}

// CPNavigationAlert.h:81-82, the header's own update of the two variant arrays. Updating an alert that was dismissed
// earlier has no effect (:74), which is the template's business - the port has no
// dismissal state on an alert - and what a caller can observe here is the two arrays it just gave.
- (void)updateTitleVariants:(NSArray<NSString *> *)newTitleVariants
           subtitleVariants:(NSArray<NSString *> *)newSubtitleVariants
{
    _titleVariants = [newTitleVariants copy] ?: @[];
    _subtitleVariants = [newSubtitleVariants copy] ?: @[];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_titleVariants forKey:@"CPNavigationAlertTitleVariants"];
    [coder encodeObject:_subtitleVariants forKey:@"CPNavigationAlertSubtitleVariants"];
    [coder encodeDouble:_duration forKey:@"CPNavigationAlertDuration"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _titleVariants = [coder decodeObjectForKey:@"CPNavigationAlertTitleVariants"] ?: @[];
        _subtitleVariants = [coder decodeObjectForKey:@"CPNavigationAlertSubtitleVariants"] ?: @[];
        _duration = [coder decodeDoubleForKey:@"CPNavigationAlertDuration"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
