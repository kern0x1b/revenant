#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import "RevenantTraitStyle.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const RevenantIdiomKey = @"UITraitCollectionBuiltinTrait-_UITraitNameUserInterfaceIdiom";
static NSString *const RevenantScaleKey = @"UITraitCollectionBuiltinTrait-_UITraitNameDisplayScale";
static NSString *const RevenantHorizontalKey = @"UITraitCollectionBuiltinTrait-_UITraitNameHorizontalSizeClass";
static NSString *const RevenantVerticalKey = @"UITraitCollectionBuiltinTrait-_UITraitNameVerticalSizeClass";
static NSString *const RevenantStyleKey = @"UITraitCollectionBuiltinTrait-_UITraitNameUserInterfaceStyle";

static BOOL revenant_orientation_forced;
static UIInterfaceOrientation revenant_forced_orientation;

static UITraitCollection *revenant_make(Class cls, UIUserInterfaceIdiom idiom, CGFloat scale, UIUserInterfaceSizeClass horizontal, UIUserInterfaceSizeClass vertical);

static UIInterfaceOrientation revenant_interface_orientation(void)
{
    if (revenant_orientation_forced)
        return revenant_forced_orientation;
    UIApplication *application = [UIApplication sharedApplication];
    UIInterfaceOrientation orientation = application ? application.statusBarOrientation : UIInterfaceOrientationPortrait;
    return orientation ? orientation : UIInterfaceOrientationPortrait;
}

static UIUserInterfaceSizeClass revenant_horizontal_class(UIUserInterfaceIdiom device, CGFloat width)
{
    if (device != UIUserInterfaceIdiomPhone && device != UIUserInterfaceIdiomPad)
        return UIUserInterfaceSizeClassUnspecified;
    return width > 667 ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact;
}

static UIUserInterfaceSizeClass revenant_vertical_class(UIUserInterfaceIdiom device, CGFloat height)
{
    if (device == UIUserInterfaceIdiomPad)
        return UIUserInterfaceSizeClassRegular;
    if (device != UIUserInterfaceIdiomPhone)
        return UIUserInterfaceSizeClassUnspecified;
    return height >= 480 ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact;
}

static UITraitCollection *revenant_trait_collection_for(UIUserInterfaceIdiom screenIdiom, UIUserInterfaceIdiom device, CGFloat scale, CGSize bounds)
{
    UITraitCollection *collection = revenant_make([UITraitCollection class], screenIdiom, scale, revenant_horizontal_class(device, bounds.width), revenant_vertical_class(device, bounds.height));
    revenant_set_trait_style(collection, UIUserInterfaceStyleLight);
    revenant_apply_screen_trait_extras(collection);
    revenant_set_screen_trait_force_touch(collection);
    return collection;
}

static CGSize revenant_bounds_for_orientation(UIScreen *screen, UIInterfaceOrientation orientation)
{
    CGSize natural = screen.bounds.size;
    return UIInterfaceOrientationIsLandscape(orientation) ? CGSizeMake(natural.height, natural.width) : natural;
}

static UITraitCollection *revenant_screen_traits(UIScreen *screen)
{
    UIScreen *main = [UIScreen mainScreen];
    if (!screen)
        screen = main;
    UIInterfaceOrientation orientation = revenant_interface_orientation();
    UIUserInterfaceIdiom device = [UIDevice currentDevice].userInterfaceIdiom;
    if (screen != main)
        return revenant_trait_collection_for(UIUserInterfaceIdiomUnspecified, device, screen.scale, screen.bounds.size);
    static UITraitCollection *cached[2];
    static CGFloat cachedScale;
    static CGSize cachedBounds;
    static UIUserInterfaceIdiom cachedDevice;
    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
    CGFloat scale = screen.scale;
    CGSize natural = screen.bounds.size;
    if (cachedScale != scale || !CGSizeEqualToSize(cachedBounds, natural) || cachedDevice != device) {
        cached[0] = nil;
        cached[1] = nil;
        cachedScale = scale;
        cachedBounds = natural;
        cachedDevice = device;
    }
    if (!cached[landscape])
        cached[landscape] = revenant_trait_collection_for(device, device, scale, revenant_bounds_for_orientation(screen, orientation));
    return cached[landscape];
}

static void revenant_collect_views(UIView *view, NSMutableOrderedSet *found)
{
    UIResponder *next = view.nextResponder;
    if ([next isKindOfClass:[UIViewController class]] && ((UIViewController *)next).view == view)
        [found addObject:next];
    [found addObject:view];
    for (UIView *subview in view.subviews)
        revenant_collect_views(subview, found);
}

static void revenant_collect_controllers(UIViewController *controller, NSMutableOrderedSet *found)
{
    if (!controller || [found containsObject:controller])
        return;
    [found addObject:controller];
    if (controller.isViewLoaded)
        revenant_collect_views(controller.view, found);
    for (UIViewController *child in controller.childViewControllers)
        revenant_collect_controllers(child, found);
    UIViewController *presented = controller.presentedViewController;
    if (presented && presented.presentingViewController == controller)
        revenant_collect_controllers(presented, found);
}

static void revenant_deliver_trait_changes(NSArray *environments, void (^change)(void))
{
    NSMutableOrderedSet *found = [NSMutableOrderedSet orderedSet];
    for (id environment in environments) {
        if ([environment isKindOfClass:[UIViewController class]]) {
            revenant_collect_controllers(environment, found);
        } else if ([environment isKindOfClass:[UIView class]]) {
            revenant_collect_views(environment, found);
            if ([environment isKindOfClass:[UIWindow class]])
                revenant_collect_controllers([(UIWindow *)environment rootViewController], found);
        } else {
            [found addObject:environment];
        }
    }
    NSMutableArray *previous = [NSMutableArray arrayWithCapacity:found.count];
    for (id<UITraitEnvironment> environment in found)
        [previous addObject:environment.traitCollection];
    change();
    revenant_call_trait_change_observers([found array], previous);
    NSUInteger index = 0;
    for (id<UITraitEnvironment> environment in found) {
        UITraitCollection *before = [previous objectAtIndex:index++];
        if (![before isEqual:environment.traitCollection])
            [environment traitCollectionDidChange:before];
    }
}

static void revenant_orientation_changed(NSNotification *notification)
{
    NSNumber *old = [notification.userInfo objectForKey:UIApplicationStatusBarOrientationUserInfoKey];
    UIApplication *application = notification.object;
    if (!old || !application)
        return;
    NSMutableArray *environments = [NSMutableArray arrayWithObject:[UIScreen mainScreen]];
    [environments addObjectsFromArray:application.windows];
    revenant_orientation_forced = YES;
    revenant_forced_orientation = (UIInterfaceOrientation)old.integerValue;
    revenant_deliver_trait_changes(environments, ^{
        revenant_orientation_forced = NO;
    });
    revenant_orientation_forced = NO;
}

static NSString *revenant_idiom_name(UIUserInterfaceIdiom idiom)
{
    switch (idiom) {
    case UIUserInterfaceIdiomPhone:
        return @"Phone";
    case UIUserInterfaceIdiomPad:
        return @"Pad";
    default:
        return [NSString stringWithFormat:@"%ld", (long)idiom];
    }
}

static NSString *revenant_size_class_name(UIUserInterfaceSizeClass sizeClass)
{
    switch (sizeClass) {
    case UIUserInterfaceSizeClassCompact:
        return @"Compact";
    case UIUserInterfaceSizeClassRegular:
        return @"Regular";
    default:
        return [NSString stringWithFormat:@"%ld", (long)sizeClass];
    }
}

@implementation UITraitCollection {
    UIUserInterfaceIdiom _userInterfaceIdiom;
    CGFloat _displayScale;
    UIUserInterfaceSizeClass _horizontalSizeClass;
    UIUserInterfaceSizeClass _verticalSizeClass;
}

+ (void)load
{
    if (objc_getClass("UITraitCollection") != self)
        return;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
        revenant_orientation_changed(notification);
    }];
}

+ (UITraitCollection *)revenant_traitCollectionForScreen:(UIScreen *)screen
{
    return revenant_screen_traits(screen);
}

+ (UITraitCollection *)revenant_traitCollectionWithScreenIdiom:(UIUserInterfaceIdiom)screenIdiom deviceIdiom:(UIUserInterfaceIdiom)deviceIdiom scale:(CGFloat)scale bounds:(CGSize)bounds
{
    return revenant_trait_collection_for(screenIdiom, deviceIdiom, scale, bounds);
}

+ (void)revenant_deliverChangesInEnvironments:(NSArray *)environments change:(void (^)(void))change
{
    revenant_deliver_trait_changes(environments, change);
}

@dynamic forceTouchCapability;
@dynamic layoutDirection;
@dynamic preferredContentSizeCategory;
@dynamic displayGamut;
@dynamic userInterfaceStyle;
@dynamic accessibilityContrast;
@dynamic userInterfaceLevel;
@dynamic legibilityWeight;
@dynamic activeAppearance;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (UITraitCollection *)traitCollectionWithTraitsFromCollections:(NSArray *)traitCollections
{
    UIUserInterfaceIdiom idiom = UIUserInterfaceIdiomUnspecified;
    CGFloat scale = 0;
    UIUserInterfaceSizeClass horizontal = UIUserInterfaceSizeClassUnspecified;
    UIUserInterfaceSizeClass vertical = UIUserInterfaceSizeClassUnspecified;
    UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
    for (UITraitCollection *collection in traitCollections) {
        if (![collection isKindOfClass:[UITraitCollection class]])
            [NSException raise:NSInvalidArgumentException format:@"Arguments to traitCollectionWithTraitsFromCollections: must all be of type UITraitCollection"];
        if (collection->_userInterfaceIdiom != UIUserInterfaceIdiomUnspecified)
            idiom = collection->_userInterfaceIdiom;
        if (collection->_displayScale != 0)
            scale = collection->_displayScale;
        if (collection->_horizontalSizeClass != UIUserInterfaceSizeClassUnspecified)
            horizontal = collection->_horizontalSizeClass;
        if (collection->_verticalSizeClass != UIUserInterfaceSizeClassUnspecified)
            vertical = collection->_verticalSizeClass;
        if (revenant_trait_style(collection) != UIUserInterfaceStyleUnspecified)
            style = revenant_trait_style(collection);
    }
    UITraitCollection *merged = revenant_make(self, idiom, scale, horizontal, vertical);
    revenant_set_trait_style(merged, style);
    revenant_apply_trait_extras(merged, revenant_merge_trait_extras(traitCollections));
    return merged;
}

+ (UITraitCollection *)traitCollectionWithUserInterfaceIdiom:(UIUserInterfaceIdiom)idiom
{
    return revenant_make(self, idiom, 0, UIUserInterfaceSizeClassUnspecified, UIUserInterfaceSizeClassUnspecified);
}

+ (UITraitCollection *)traitCollectionWithDisplayScale:(CGFloat)scale
{
    return revenant_make(self, UIUserInterfaceIdiomUnspecified, scale, UIUserInterfaceSizeClassUnspecified, UIUserInterfaceSizeClassUnspecified);
}

+ (UITraitCollection *)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
{
    return revenant_make(self, UIUserInterfaceIdiomUnspecified, 0, horizontalSizeClass, UIUserInterfaceSizeClassUnspecified);
}

+ (UITraitCollection *)traitCollectionWithVerticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
{
    return revenant_make(self, UIUserInterfaceIdiomUnspecified, 0, UIUserInterfaceSizeClassUnspecified, verticalSizeClass);
}

static UITraitCollection *revenant_make(Class cls, UIUserInterfaceIdiom idiom, CGFloat scale, UIUserInterfaceSizeClass horizontal, UIUserInterfaceSizeClass vertical)
{
    UITraitCollection *collection = [[cls alloc] init];
    collection->_userInterfaceIdiom = idiom;
    collection->_displayScale = scale;
    collection->_horizontalSizeClass = horizontal;
    collection->_verticalSizeClass = vertical;
    return collection;
}

- (instancetype)init
{
    if ((self = [super init]))
        _userInterfaceIdiom = UIUserInterfaceIdiomUnspecified;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _userInterfaceIdiom = [coder containsValueForKey:RevenantIdiomKey] ? (UIUserInterfaceIdiom)[coder decodeIntegerForKey:RevenantIdiomKey] : UIUserInterfaceIdiomUnspecified;
        _displayScale = (CGFloat)[coder decodeDoubleForKey:RevenantScaleKey];
        _horizontalSizeClass = (UIUserInterfaceSizeClass)[coder decodeIntegerForKey:RevenantHorizontalKey];
        _verticalSizeClass = (UIUserInterfaceSizeClass)[coder decodeIntegerForKey:RevenantVerticalKey];
        revenant_set_trait_style(self, (UIUserInterfaceStyle)[coder decodeIntegerForKey:RevenantStyleKey]);
        revenant_decode_trait_extras(self, coder);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_userInterfaceIdiom != UIUserInterfaceIdiomUnspecified)
        [coder encodeInteger:_userInterfaceIdiom forKey:RevenantIdiomKey];
    if (_displayScale != 0)
        [coder encodeDouble:_displayScale forKey:RevenantScaleKey];
    if (_horizontalSizeClass != UIUserInterfaceSizeClassUnspecified)
        [coder encodeInteger:_horizontalSizeClass forKey:RevenantHorizontalKey];
    if (_verticalSizeClass != UIUserInterfaceSizeClassUnspecified)
        [coder encodeInteger:_verticalSizeClass forKey:RevenantVerticalKey];
    if (revenant_trait_style(self) != UIUserInterfaceStyleUnspecified)
        [coder encodeInteger:revenant_trait_style(self) forKey:RevenantStyleKey];
    revenant_encode_trait_extras(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (UIUserInterfaceIdiom)userInterfaceIdiom
{
    return _userInterfaceIdiom;
}

- (CGFloat)displayScale
{
    return _displayScale;
}

- (UIUserInterfaceSizeClass)horizontalSizeClass
{
    return _horizontalSizeClass;
}

- (UIUserInterfaceSizeClass)verticalSizeClass
{
    return _verticalSizeClass;
}

- (void)revenant_setUserInterfaceIdiom:(UIUserInterfaceIdiom)idiom
{
    _userInterfaceIdiom = idiom;
}

- (void)revenant_setDisplayScale:(CGFloat)scale
{
    _displayScale = scale;
}

- (void)revenant_setHorizontalSizeClass:(UIUserInterfaceSizeClass)sizeClass
{
    _horizontalSizeClass = sizeClass;
}

- (void)revenant_setVerticalSizeClass:(UIUserInterfaceSizeClass)sizeClass
{
    _verticalSizeClass = sizeClass;
}

- (BOOL)containsTraitsInCollection:(UITraitCollection *)trait
{
    if (![trait isKindOfClass:[UITraitCollection class]])
        return YES;
    if (trait->_userInterfaceIdiom != UIUserInterfaceIdiomUnspecified && trait->_userInterfaceIdiom != _userInterfaceIdiom)
        return NO;
    if (trait->_displayScale != 0 && trait->_displayScale != _displayScale)
        return NO;
    if (trait->_horizontalSizeClass != UIUserInterfaceSizeClassUnspecified && trait->_horizontalSizeClass != _horizontalSizeClass)
        return NO;
    if (revenant_trait_style(trait) != UIUserInterfaceStyleUnspecified && revenant_trait_style(trait) != revenant_trait_style(self))
        return NO;
    if (!revenant_trait_extras_contained(self, trait))
        return NO;
    return trait->_verticalSizeClass == UIUserInterfaceSizeClassUnspecified || trait->_verticalSizeClass == _verticalSizeClass;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UITraitCollection class]])
        return NO;
    UITraitCollection *other = object;
    return other->_userInterfaceIdiom == _userInterfaceIdiom && other->_displayScale == _displayScale &&
           other->_horizontalSizeClass == _horizontalSizeClass && other->_verticalSizeClass == _verticalSizeClass &&
           revenant_trait_style(other) == revenant_trait_style(self) && revenant_trait_extras_equal(self, other);
}

- (NSUInteger)hash
{
    NSUInteger scale = (NSUInteger)(_displayScale * 100);
    return ((NSUInteger)(_userInterfaceIdiom + 1) << 24) ^ (scale << 8) ^ ((NSUInteger)_horizontalSizeClass << 4) ^ (NSUInteger)_verticalSizeClass ^
           ((NSUInteger)revenant_trait_style(self) << 20) ^ revenant_trait_extras_hash(self);
}

- (NSString *)description
{
    NSMutableArray *traits = [NSMutableArray array];
    if (_userInterfaceIdiom != UIUserInterfaceIdiomUnspecified)
        [traits addObject:[@"UserInterfaceIdiom = " stringByAppendingString:revenant_idiom_name(_userInterfaceIdiom)]];
    if (_displayScale != 0)
        [traits addObject:[NSString stringWithFormat:@"DisplayScale = %g", (double)_displayScale]];
    if (_horizontalSizeClass != UIUserInterfaceSizeClassUnspecified)
        [traits addObject:[@"HorizontalSizeClass = " stringByAppendingString:revenant_size_class_name(_horizontalSizeClass)]];
    if (_verticalSizeClass != UIUserInterfaceSizeClassUnspecified)
        [traits addObject:[@"VerticalSizeClass = " stringByAppendingString:revenant_size_class_name(_verticalSizeClass)]];
    if (revenant_trait_style(self) != UIUserInterfaceStyleUnspecified)
        [traits addObject:[@"UserInterfaceStyle = " stringByAppendingString:revenant_trait_style(self) == UIUserInterfaceStyleDark ? @"Dark" : @"Light"]];
    revenant_add_trait_extras_description(self, traits);
    return [NSString stringWithFormat:@"<%@: %p; %@>", [self class], self, [traits componentsJoinedByString:@", "]];
}

@end
