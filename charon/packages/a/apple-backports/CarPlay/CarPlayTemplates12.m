#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <math.h>
#import "CharonCarPlayTemplate.h"
#import "CharonCarPlay174.h"

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

- (id)templateApplicationScene
{
    return _templateApplicationScene;
}

- (void)setTemplateApplicationScene:(id)templateApplicationScene
{
    _templateApplicationScene = templateApplicationScene;
}

@end

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

- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    return nil;
}

@end

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

@implementation CPGridButton {
    NSArray<NSString *> *_titleVariants;
    UIImage *_image;
    BOOL _enabled;
    void (^_handler)(CPGridButton *);
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

- (void)charon_setImage:(UIImage *)image
{
    _image = image;
}

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
    _titleVariants = [titleVariants copy] ?: @[];
}

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

@implementation CPTravelEstimates {
    NSMeasurement<NSUnitLength *> *_distanceRemaining;
    NSTimeInterval _timeRemaining;
    NSMeasurement<NSUnitLength *> *_charon_distanceRemainingToDisplay;
}

@synthesize distanceRemaining = _distanceRemaining;
@synthesize timeRemaining = _timeRemaining;

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
    self = [self initWithTitle:title style:style handler:handler];
    if (self) {
        [self charon_setColor:color];
    }
    return self;
}

- (void)charon_setColor:(UIColor *)color
{
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
    _titleVariants = [newTitleVariants copy] ?: @[];
    _subtitleVariants = [newSubtitleVariants copy] ?: @[];
    _imageSet = newImageSet;
    _image = newImageArray.firstObject;
_duration = newDuration;
        _primaryAction = newPrimaryAction;
        _secondaryAction = newSecondaryAction;
}

- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants
                     subtitleVariants:(NSArray<NSString *> *)subtitleVariants
                             imageSet:(CPImageSet *)imageSet
                        primaryAction:(CPAlertAction *)primaryAction
                      secondaryAction:(CPAlertAction *)secondaryAction
                             duration:(NSTimeInterval)duration
{
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

- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants
                     subtitleVariants:(NSArray<NSString *> *)subtitleVariants
                                image:(UIImage *)image
                        primaryAction:(CPAlertAction *)primaryAction
                      secondaryAction:(CPAlertAction *)secondaryAction
                             duration:(NSTimeInterval)duration
{
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
