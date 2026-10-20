#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>
#import "RevenantBackdrop.h"
#import "RevenantCustomTransition.h"
#import "RevenantSheet.h"
#include "RevenantSheetShadow.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSString *const UISheetPresentationControllerDetentIdentifierMedium = @"com.apple.UIKit.medium";
NSString *const UISheetPresentationControllerDetentIdentifierLarge = @"com.apple.UIKit.large";
const CGFloat UISheetPresentationControllerAutomaticDimension = CGFLOAT_MAX;

static const CGFloat revenant_sheet_corner_radius = 10;
static const CGFloat revenant_sheet_top_offset = 10;
static const CGFloat revenant_sheet_top_offset_compact_height = 8;
static const CGFloat revenant_sheet_maximum_depth = 2;
static const NSTimeInterval revenant_sheet_transition_duration = 0.4;
static const CGFloat revenant_sheet_spring_response = 0.3441442326;
static const CGFloat revenant_sheet_spring_damping = 1;
static const CGFloat revenant_sheet_medium_threshold = 568;
static const CGFloat revenant_sheet_medium_small = 0.63;
static const CGFloat revenant_sheet_medium_large = 0.56;
static const CGFloat revenant_sheet_grabber_width = 36;
static const CGFloat revenant_sheet_grabber_height = 5;
static const CGFloat revenant_sheet_grabber_spacing = 5;
static const CGFloat revenant_sheet_rubber_band_coefficient = 0.55;
static const CGFloat revenant_sheet_deceleration_rate = 0.99;
static const CGFloat revenant_sheet_flick_speed = 1000;
static const CGFloat revenant_sheet_top_extent = 100;
static const CGFloat revenant_sheet_bottom_extent = 200;
static const CGFloat revenant_sheet_bottom_extent_fraction = 0.25;
static const CGFloat revenant_sheet_spring_damping_fast = 0.8;
static const CGFloat revenant_sheet_minimum_speed = 250;
static const NSTimeInterval revenant_sheet_swipe_interval = 0.4;

static CGFloat revenant_clamp01(CGFloat value)
{
    return value < 0 ? 0 : value > 1 ? 1 : value;
}

static CGFloat revenant_sheet_content_margin(UIWindow *window, CGFloat width)
{
    UIEdgeInsets insets = window ? window.safeAreaInsets : UIEdgeInsetsZero;
    BOOL both = insets.left > 0 && insets.right > 0;
    return width > 393 && !both ? 20 : 16;
}

static BOOL revenant_sheet_has_home_button(UIWindow *window)
{
    return !(window && window.safeAreaInsets.bottom > 0);
}

static CGFloat revenant_sheet_display_corner_radius(UIWindow *window)
{
    if (revenant_sheet_has_home_button(window))
        return 0;
    UIScreen *screen = window.screen;
    SEL selector = NSSelectorFromString(@"_displayCornerRadius");
    return [screen respondsToSelector:selector] ? ((CGFloat (*)(id, SEL))objc_msgSend)(screen, selector) : 0;
}

static UIColor *revenant_sheet_dimming_color(UITraitCollection *traits)
{
    return [UIColor colorWithWhite:0 alpha:traits.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.48 : 0.2];
}

static UIColor *revenant_sheet_grabber_color(void)
{
    return [UIColor tertiaryLabelColor];
}

static CGFloat revenant_sheet_rubber_band(CGFloat overshoot, CGFloat extent)
{
    if (extent <= 0 || overshoot <= 0)
        return 0;
    return extent * (1 - 1 / (overshoot * revenant_sheet_rubber_band_coefficient / extent + 1));
}

static CGFloat revenant_sheet_effective_velocity(CGFloat velocity)
{
    return fabs(velocity) < revenant_sheet_minimum_speed ? 0 : velocity;
}

static UIColor *revenant_sheet_dimming_background(UITraitCollection *traits, CGFloat displayed, CGFloat lightened)
{
    CGFloat dimAlpha = (traits.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.48 : 0.2) * displayed;
    if (lightened <= 0)
        return [UIColor colorWithWhite:0 alpha:dimAlpha];
    UITraitCollection *elevated = [UITraitCollection traitCollectionWithTraitsFromCollections:@[
        [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark],
        [UITraitCollection traitCollectionWithUserInterfaceLevel:UIUserInterfaceLevelElevated] ]];
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [[[UIColor systemBackgroundColor] resolvedColorWithTraitCollection:elevated] getRed:&r green:&g blue:&b alpha:&a];
    CGFloat largest = MAX(r, MAX(g, b));
    if (largest <= 0)
        return [UIColor colorWithWhite:0 alpha:dimAlpha];
    CGFloat lightAlpha = largest * lightened;
    CGFloat alpha = dimAlpha + lightAlpha * (1 - dimAlpha);
    if (alpha <= 0)
        return [UIColor clearColor];
    CGFloat keep = lightAlpha * (1 - dimAlpha) / alpha;
    return [UIColor colorWithRed:r / largest * keep green:g / largest * keep blue:b / largest * keep alpha:alpha];
}


static UIView *revenant_sheet_first_responder(UIView *view)
{
    if (view.isFirstResponder)
        return view;
    for (UIView *subview in view.subviews) {
        UIView *found = revenant_sheet_first_responder(subview);
        if (found)
            return found;
    }
    return nil;
}

static BOOL revenant_sheet_first_responder_in(UIView *view)
{
    return revenant_sheet_first_responder(view) != nil;
}

#pragma mark - Detents

typedef NS_ENUM(NSInteger, RevenantDetentType) {
    RevenantDetentCustom,
    RevenantDetentLarge,
    RevenantDetentMedium
};

@implementation RevenantSheetDetentContext {
    UITraitCollection *_traits;
    CGFloat _maximum;
    CGRect _bounds;
}

- (instancetype)initWithTraitCollection:(UITraitCollection *)traits maximumDetentValue:(CGFloat)maximum containerBounds:(CGRect)bounds
{
    if ((self = [super init])) {
        _traits = traits;
        _maximum = maximum;
        _bounds = bounds;
    }
    return self;
}

- (UITraitCollection *)containerTraitCollection { return _traits; }
- (CGFloat)maximumDetentValue { return _maximum; }
- (CGRect)_containerBounds { return _bounds; }

@end

@implementation UISheetPresentationControllerDetent {
    RevenantDetentType _type;
    NSString *_identifier;
    CGFloat (^_resolver)(id context);
}

- (instancetype)initWithRevenantType:(RevenantDetentType)type identifier:(NSString *)identifier resolver:(CGFloat (^)(id context))resolver
{
    if ((self = [super init])) {
        _type = type;
        _identifier = [identifier copy];
        _resolver = [resolver copy];
    }
    return self;
}

+ (instancetype)mediumDetent
{
    return [[self alloc] initWithRevenantType:RevenantDetentMedium identifier:UISheetPresentationControllerDetentIdentifierMedium resolver:nil];
}

+ (instancetype)largeDetent
{
    return [[self alloc] initWithRevenantType:RevenantDetentLarge identifier:UISheetPresentationControllerDetentIdentifierLarge resolver:nil];
}

+ (instancetype)revenant_customDetentWithIdentifier:(NSString *)identifier resolver:(CGFloat (^)(id context))resolver
{
    NSString *name = identifier ?: [@"com.apple.UIKit.dynamic." stringByAppendingString:[[NSUUID UUID] UUIDString]];
    return [[self alloc] initWithRevenantType:RevenantDetentCustom identifier:name resolver:resolver];
}

- (NSString *)revenant_identifier
{
    return _identifier;
}

- (CGFloat)revenant_resolvedValueInContext:(id)context
{
    RevenantSheetDetentContext *known = context;
    switch (_type) {
    case RevenantDetentLarge:
        return known.maximumDetentValue;
    case RevenantDetentMedium: {
        if (known.containerTraitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact)
            return CGFLOAT_MAX;
        CGRect bounds = [known _containerBounds];
        return known.maximumDetentValue * (CGRectGetHeight(bounds) > revenant_sheet_medium_threshold ? revenant_sheet_medium_large : revenant_sheet_medium_small);
    }
    case RevenantDetentCustom:
        return _resolver ? _resolver(context) : CGFLOAT_MAX;
    }
    return CGFLOAT_MAX;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UISheetPresentationControllerDetent class]])
        return NO;
    UISheetPresentationControllerDetent *other = object;
    return _type != RevenantDetentCustom && other->_type == _type && [other->_identifier isEqualToString:_identifier];
}

- (NSString *)description
{
    static NSString *const names[] = { @"custom", @"large", @"medium" };
    return [NSString stringWithFormat:@"<%@: %p: _type=%@, _identifier=%@>", NSStringFromClass([self class]), self, names[_type], _identifier];
}

@end

#pragma mark - Layout

@interface RevenantSheetLayoutInfo : NSObject
@property (nonatomic, weak) RevenantSheetLayoutInfo *parent;
@property (nonatomic, weak) RevenantSheetLayoutInfo *child;
@property (nonatomic, weak) UIView *container;
@property (nonatomic, weak) UIView *view;
@property (nonatomic, weak) UISheetPresentationController *sheet;
@property (nonatomic, assign) BOOL root;
@property (nonatomic, assign) BOOL presented;
@property (nonatomic, assign) BOOL wantsGrabber;
@property (nonatomic, assign) BOOL edgeAttachedInCompactHeight;
@property (nonatomic, assign) BOOL widthFollowsPreferredContentSize;
@property (nonatomic, assign) CGFloat preferredWidth;
@property (nonatomic, assign) CGFloat preferredCornerRadius;
@property (nonatomic, assign) CGFloat offset;
@property (nonatomic, copy) NSArray *detentOffsets;
@property (nonatomic, assign) NSUInteger dimmingIndex;
@property (nonatomic, assign) CGRect rootFrame;
@property (nonatomic, assign) CGAffineTransform savedTransform;
@property (nonatomic, assign) CGFloat savedCornerRadius;
@property (nonatomic, assign) BOOL savedMasksToBounds;
@end

@implementation RevenantSheetLayoutInfo

@synthesize parent = _parent;
@synthesize child = _child;
@synthesize container = _container;
@synthesize view = _view;
@synthesize sheet = _sheet;
@synthesize root = _root;
@synthesize presented = _presented;
@synthesize wantsGrabber = _wantsGrabber;
@synthesize edgeAttachedInCompactHeight = _edgeAttachedInCompactHeight;
@synthesize widthFollowsPreferredContentSize = _widthFollowsPreferredContentSize;
@synthesize preferredWidth = _preferredWidth;
@synthesize preferredCornerRadius = _preferredCornerRadius;
@synthesize offset = _offset;
@synthesize detentOffsets = _detentOffsets;
@synthesize dimmingIndex = _dimmingIndex;
@synthesize rootFrame = _rootFrame;
@synthesize savedTransform = _savedTransform;
@synthesize savedCornerRadius = _savedCornerRadius;
@synthesize savedMasksToBounds = _savedMasksToBounds;

- (UITraitCollection *)traits
{
    return _container.traitCollection;
}

- (BOOL)verticallyCompact
{
    return [self traits].verticalSizeClass == UIUserInterfaceSizeClassCompact;
}

- (UIEdgeInsets)safeInsets
{
    return _container.safeAreaInsets;
}

- (BOOL)forcedFullScreen
{
    return !_root && [self verticallyCompact] && !_edgeAttachedInCompactHeight;
}

- (BOOL)functionallyFullScreen
{
    return _root || [self forcedFullScreen];
}

- (UIEdgeInsets)margins
{
    UIEdgeInsets insets = [self safeInsets];
    BOOL phone = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
    BOOL single = phone && !revenant_sheet_has_home_button(_container.window) && [self traits].horizontalSizeClass == UIUserInterfaceSizeClassCompact;
    CGFloat vertical = [self verticallyCompact] ? revenant_sheet_top_offset_compact_height : (single ? 1 : 2) * revenant_sheet_top_offset;
    insets.top += vertical;
    insets.bottom += vertical;
    return insets;
}

- (CGRect)stackAlignmentFrame
{
    CGRect bounds = _container.bounds;
    UIEdgeInsets margins = [self margins];
    CGFloat available = CGRectGetWidth(bounds) - margins.left - margins.right;
    CGFloat width = _widthFollowsPreferredContentSize && [self verticallyCompact] ? MIN(_preferredWidth, available) : available;
    return CGRectMake(margins.left + (available - width) / 2, margins.top, width, CGRectGetHeight(bounds) - margins.top);
}

- (CGRect)fullHeightFrame
{
    if (_root)
        return _rootFrame;
    return [self forcedFullScreen] ? _container.bounds : [self stackAlignmentFrame];
}

- (CGRect)untransformedFrame
{
    CGRect frame = [self fullHeightFrame];
    if (!_root)
        frame.origin.y = _offset;
    return frame;
}

- (CGFloat)maximumDetentValue
{
    return CGRectGetHeight([self fullHeightFrame]) - [self safeInsets].bottom;
}

- (CGFloat)offsetForDetentValue:(CGFloat)value
{
    return CGRectGetMaxY(_container.bounds) - [self safeInsets].bottom - MIN(value, [self maximumDetentValue]);
}

- (CGFloat)fullHeightOffset
{
    return CGRectGetMinY([self fullHeightFrame]);
}

- (CGFloat)dismissOffset
{
    return CGRectGetMaxY(_container.bounds);
}

- (CGFloat)currentOffset
{
    return _root ? CGRectGetMinY(_rootFrame) : _offset;
}

- (NSArray *)activeDetentOffsets
{
    if ([self functionallyFullScreen])
        return @[ @([self fullHeightOffset]) ];
    return _detentOffsets;
}

- (NSUInteger)activeDimmingIndex
{
    return [self functionallyFullScreen] ? 0 : _dimmingIndex;
}

- (CGFloat)percentFullHeight
{
    CGFloat full = CGRectGetMinY([self stackAlignmentFrame]);
    NSArray *detents = [self activeDetentOffsets];
    if (!detents.count || ([detents[0] doubleValue] != full && ![self functionallyFullScreen]))
        return 0;
    CGFloat next = detents.count > 1 ? [detents[1] doubleValue] : [self dismissOffset];
    if (full == next)
        return 1;
    return revenant_clamp01(([self currentOffset] - next) / (full - next));
}

- (CGFloat)percentPresented
{
    NSArray *detents = [self activeDetentOffsets];
    CGFloat smallest = detents.count ? [detents.lastObject doubleValue] : [self fullHeightOffset];
    CGFloat dismiss = [self dismissOffset];
    if (smallest == dismiss)
        return 1;
    return revenant_clamp01(([self currentOffset] - dismiss) / (smallest - dismiss));
}

- (BOOL)stacksWithChild
{
    return _child && CGRectEqualToRect([self stackAlignmentFrame], [_child stackAlignmentFrame]);
}

- (BOOL)scalesDownBehindDescendants
{
    if (UIAccessibilityIsReduceMotionEnabled() || [self verticallyCompact])
        return NO;
    return CGRectGetHeight(_container.bounds) == CGRectGetHeight(_container.window.screen.bounds) || !_root;
}

- (CGFloat)proposedDepthLevel
{
    if (![self stacksWithChild] || ![self scalesDownBehindDescendants])
        return 0;
    return [_child proposedDepthLevel] + [_child percentFullHeight];
}

- (CGFloat)depthLevel
{
    if (!_presented)
        return 0;
    BOOL flag = _parent ? [_parent stacksWithChild] : YES;
    if ([self percentFullHeight] == 0 && flag && _parent)
        return [_parent depthLevel];
    return [self proposedDepthLevel];
}

- (CGFloat)percentFullScreen
{
    if ([self forcedFullScreen])
        return 1;
    return _root ? revenant_clamp01(1 - [self depthLevel]) : 0;
}

- (CGRect)fullHeightUntransformedFrameForDepthLevel
{
    if (_parent && [_parent stacksWithChild] && [_parent depthLevel] == [self depthLevel])
        return [_parent fullHeightUntransformedFrameForDepthLevel];
    return [self fullHeightFrame];
}

- (CGAffineTransform)transform
{
    CGFloat depth = [self depthLevel];
    if (depth <= 0)
        return CGAffineTransformIdentity;
    CGRect a = [self untransformedFrame];
    CGRect b = [self fullHeightUntransformedFrameForDepthLevel];
    CGFloat margin = revenant_sheet_content_margin(_container.window, CGRectGetWidth(a));
    CGFloat k = 2 * (1 - exp2(-MIN(depth, revenant_sheet_maximum_depth - 1)));
    CGFloat scale = CGRectGetWidth(b) == 0 ? 1 : 1 - 2 * margin * k / CGRectGetWidth(b);
    CGFloat sum = CGRectGetHeight(a) * (1 - scale) / 2 + (CGRectGetMinY(a) - CGRectGetMinY(b)) * (1 - scale)
                + revenant_sheet_top_offset * k * revenant_clamp01(revenant_sheet_maximum_depth - depth)
                + revenant_clamp01(depth) * (CGRectGetMinY(b) - CGRectGetMinY([self stackAlignmentFrame]));
    return CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, -sum / scale), CGAffineTransformMakeScale(scale, scale));
}

- (CGFloat)percentDimmedFromOffset
{
    NSArray *detents = [self activeDetentOffsets];
    NSUInteger index = [self activeDimmingIndex];
    CGFloat own = 0;
    if (index != NSNotFound && index < detents.count) {
        CGFloat dimmed = [detents[index] doubleValue];
        CGFloat next = index + 1 < detents.count ? [detents[index + 1] doubleValue] : [self dismissOffset];
        own = dimmed == next ? 1 : revenant_clamp01(([self currentOffset] - next) / (dimmed - next));
    }
    CGFloat child = _child ? [_child percentDimmedFromOffset] : 0;
    return own < child ? child : own;
}

- (CGFloat)percentDimmed
{
    CGFloat p = [self percentDimmedFromOffset];
    if (_parent && [_parent stacksWithChild])
        return 0;
    return _parent && [_parent percentFullScreen] == 1 ? 0 : p;
}

- (CGFloat)confinedPercentDimmed
{
    CGFloat p = [self percentDimmedFromOffset];
    if (!_parent)
        return 0;
    if ([_parent stacksWithChild]) {
        if ([_parent percentFullScreen] != 1 || [_parent scalesDownBehindDescendants])
            return 0.6 * p + ([self stacksWithChild] ? 0.2 * [_child percentDimmedFromOffset] : 0);
        return p;
    }
    return [_parent percentFullScreen] == 1 ? p : 0;
}

- (CGFloat)grabberAlpha
{
    CGFloat g = !_wantsGrabber ? 0 : _child ? 1 - [_child percentDimmedFromOffset] : 1;
    return g * (1 - [self percentFullScreen]);
}

- (CGFloat)shadowOpacity
{
    return 0.5 * (1 - [self percentDimmedFromOffset]) * [self percentPresented];
}

- (CGFloat)magicShadowOpacity
{
    if (_parent && [_parent stacksWithChild])
        return 0;
    return [self percentFullScreen] == 1 ? 0 : [self percentDimmedFromOffset];
}

- (void)getTopCornerRadius:(CGFloat *)top bottomCornerRadius:(CGFloat *)bottom
{
    CGFloat automatic = UISheetPresentationControllerAutomaticDimension, display = revenant_sheet_display_corner_radius(_container.window);
    CGFloat dismiss = revenant_sheet_corner_radius;
    CGFloat own = _root || _preferredCornerRadius == automatic ? revenant_sheet_corner_radius : _preferredCornerRadius;
    CGFloat childRadius = _child ? (_child.preferredCornerRadius == automatic ? revenant_sheet_corner_radius : _child.preferredCornerRadius) : own;
    childRadius = 0.5 * childRadius + 0.5 * revenant_sheet_corner_radius;
    CGFloat depth = [self depthLevel], dd = revenant_clamp01(depth);
    CGFloat bases[2];
    bases[0] = (1 - dd) * own + dd * childRadius;
    bases[1] = depth == 0 ? (CGRectGetWidth([self untransformedFrame]) == CGRectGetWidth(_container.bounds) ? automatic : 0) : bases[0];
    CGFloat full = [self percentFullScreen], presented = [self percentPresented];
    for (int i = 0; i < 2; i++) {
        CGFloat value = bases[i] == automatic || full == 1 ? automatic : (1 - full) * bases[i] + full * display;
        bases[i] = value == automatic && presented == 1 ? display : (1 - presented) * dismiss + presented * (value == automatic ? display : value);
    }
    *top = bases[0];
    *bottom = bases[1];
}

@end

#pragma mark - The sheet's view

@interface RevenantSheetGrabber : UIControl
@end

@implementation RevenantSheetGrabber

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGRect bounds = self.bounds;
    CGFloat dx = MIN(CGRectGetWidth(bounds) - 44, 0) / 2, dy = MIN(CGRectGetHeight(bounds) - 44, 0) / 2;
    return CGRectContainsPoint(CGRectInset(bounds, dx, dy), point);
}

@end

static const CGFloat revenant_sheet_magic_shadow_outset = 150;
static const CGFloat revenant_sheet_magic_shadow_radius = 10;

@interface RevenantSheetView : UIView <RevenantBackdropClient>
@property (nonatomic, readonly) UIView *clippingView;
@property (nonatomic, readonly) UIControl *grabber;
- (void)setTopCornerRadius:(CGFloat)top bottomCornerRadius:(CGFloat)bottom;
- (void)setMagicShadowAlpha:(CGFloat)alpha;
@end

static void revenant_sheet_free_pixels(void *info, const void *data, size_t size)
{
    free((void *)data);
}

@implementation RevenantSheetView {
    UIView *_clippingView;
    UIControl *_grabber;
    CAShapeLayer *_mask;
    CGFloat _topCornerRadius;
    CGFloat _bottomCornerRadius;
    UIView *_magicShadowView;
    CALayer *_magicShadowLayer;
    RevenantBackdrop *_magicShadowReader;
    dispatch_queue_t _magicShadowQueue;
    BOOL _magicShadowShading;
}

@synthesize clippingView = _clippingView;
@synthesize grabber = _grabber;

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _clippingView = [[UIView alloc] initWithFrame:self.bounds];
        _clippingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _mask = [CAShapeLayer layer];
        _clippingView.layer.mask = _mask;
        [self addSubview:_clippingView];
        _grabber = [[RevenantSheetGrabber alloc] initWithFrame:CGRectMake(0, 0, revenant_sheet_grabber_width, revenant_sheet_grabber_height)];
        _grabber.layer.cornerRadius = revenant_sheet_grabber_height / 2;
        _grabber.backgroundColor = revenant_sheet_grabber_color();
        _grabber.hidden = YES;
        [self addSubview:_grabber];
    }
    return self;
}

- (void)setTopCornerRadius:(CGFloat)top bottomCornerRadius:(CGFloat)bottom
{
    if (top == _topCornerRadius && bottom == _bottomCornerRadius)
        return;
    _topCornerRadius = top;
    _bottomCornerRadius = bottom;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = _clippingView.bounds;
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat top = MIN(_topCornerRadius, CGRectGetWidth(bounds) / 2), bottom = MIN(_bottomCornerRadius, CGRectGetWidth(bounds) / 2);
    [path moveToPoint:CGPointMake(CGRectGetMinX(bounds) + top, CGRectGetMinY(bounds))];
    [path addLineToPoint:CGPointMake(CGRectGetMaxX(bounds) - top, CGRectGetMinY(bounds))];
    [path addArcWithCenter:CGPointMake(CGRectGetMaxX(bounds) - top, CGRectGetMinY(bounds) + top) radius:top startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [path addLineToPoint:CGPointMake(CGRectGetMaxX(bounds), CGRectGetMaxY(bounds) - bottom)];
    [path addArcWithCenter:CGPointMake(CGRectGetMaxX(bounds) - bottom, CGRectGetMaxY(bounds) - bottom) radius:bottom startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [path addLineToPoint:CGPointMake(CGRectGetMinX(bounds) + bottom, CGRectGetMaxY(bounds))];
    [path addArcWithCenter:CGPointMake(CGRectGetMinX(bounds) + bottom, CGRectGetMaxY(bounds) - bottom) radius:bottom startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
    [path addLineToPoint:CGPointMake(CGRectGetMinX(bounds), CGRectGetMinY(bounds) + top)];
    [path addArcWithCenter:CGPointMake(CGRectGetMinX(bounds) + top, CGRectGetMinY(bounds) + top) radius:top startAngle:M_PI endAngle:3 * M_PI_2 clockwise:YES];
    [path closePath];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _mask.frame = bounds;
    _mask.path = path.CGPath;
    self.layer.shadowPath = [path CGPath];
    [CATransaction commit];
    _grabber.center = CGPointMake(CGRectGetMidX(self.bounds), revenant_sheet_grabber_spacing + revenant_sheet_grabber_height / 2);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hit = [_grabber hitTest:[self convertPoint:point toView:_grabber] withEvent:event];
    if (hit)
        return hit;
    hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

- (void)setMagicShadowAlpha:(CGFloat)alpha
{
    if (!_magicShadowView && alpha <= 0)
        return;
    if (!_magicShadowView) {
        _magicShadowView = [[UIView alloc] initWithFrame:CGRectInset(self.bounds, -revenant_sheet_magic_shadow_outset, -revenant_sheet_magic_shadow_outset)];
        _magicShadowView.userInteractionEnabled = NO;
        _magicShadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _magicShadowLayer = [CALayer layer];
        [_magicShadowView.layer addSublayer:_magicShadowLayer];
        [self insertSubview:_magicShadowView atIndex:0];
        _magicShadowReader = [[RevenantBackdrop alloc] initWithView:self client:self];
        _magicShadowQueue = dispatch_queue_create("org.revenant.sheet.shadow", DISPATCH_QUEUE_SERIAL);
    }
    _magicShadowView.alpha = alpha;
    [self revenant_updateMagicShadowReader];
}

- (void)revenant_updateMagicShadowReader
{
    if (self.window && _magicShadowView.alpha > 0) {
        _magicShadowReader.scale = self.window.screen.scale;
        [_magicShadowReader start];
    } else {
        [_magicShadowReader stop];
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self revenant_updateMagicShadowReader];
}

- (BOOL)backdropIsWanted:(RevenantBackdrop *)backdrop
{
    return !self.hidden && _magicShadowView.alpha > 0 && !_magicShadowShading;
}

- (CGRect)backdropRegion:(RevenantBackdrop *)backdrop
{
    return _magicShadowView.frame;
}

- (void)backdrop:(RevenantBackdrop *)backdrop captured:(uint8_t *)pixels width:(size_t)width height:(size_t)height rowBytes:(size_t)rowBytes rect:(CGRect)captured
{
    CGRect frame = _magicShadowView.frame;
    CGFloat scale = self.window.screen.scale;
    double cap = revenant_sheet_shadow_cap(CGRectGetWidth(frame), CGRectGetHeight(frame), revenant_sheet_magic_shadow_radius, scale);
    double x = CGRectGetMinX(captured) - CGRectGetMinX(frame), y = CGRectGetMinY(captured) - CGRectGetMinY(frame);
    double dx = CGRectGetWidth(captured) / width, dy = CGRectGetHeight(captured) / height;
    CGSize size = frame.size;
    unsigned shadowScale = (unsigned)lround(scale);
    _magicShadowShading = YES;
    dispatch_async(_magicShadowQueue, ^{
        CGImageRef image = NULL;
        if (revenant_sheet_shadow_emulator(pixels, width, height, rowBytes, x, y, dx, dy, size.width, size.height, cap, shadowScale)) {
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, rowBytes * height, revenant_sheet_free_pixels);
            image = CGImageCreate(width, height, 8, 32, rowBytes, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
            CGDataProviderRelease(provider);
            CGColorSpaceRelease(space);
        } else {
            free(pixels);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            _magicShadowLayer.frame = [self convertRect:captured toView:_magicShadowView];
            _magicShadowLayer.contents = (__bridge id)image;
            [CATransaction commit];
            CGImageRelease(image);
            _magicShadowShading = NO;
        });
    });
}

@end

#pragma mark - The sheet

@interface UISheetPresentationController () <UIGestureRecognizerDelegate>
- (void)revenant_animateToOffset:(CGFloat)offset velocity:(CGFloat)velocity completion:(void (^)(void))completion;
- (void)revenant_embedContent;
- (CGFloat)revenant_dismissOffset;
- (CGFloat)revenant_selectedOffset;
- (void)revenant_setOffset:(CGFloat)offset;
- (void)revenant_applyLayout;
- (void)revenant_linkParent;
- (BOOL)revenant_shouldDismiss;
- (BOOL)revenant_takeInteractiveDismissal:(id<UIViewControllerContextTransitioning>)context;
@end

@interface RevenantSheetAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, weak) UISheetPresentationController *sheet;
@end

@implementation RevenantSheetAnimator
@synthesize sheet = _sheet;

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context
{
    return context.isAnimated ? revenant_sheet_transition_duration : 0;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context
{
    UISheetPresentationController *sheet = _sheet;
    BOOL presenting = [context viewControllerForKey:UITransitionContextToViewControllerKey] == sheet.presentedViewController;
    if (!presenting && [sheet revenant_takeInteractiveDismissal:context])
        return;
    if (presenting) {
        [sheet revenant_linkParent];
        [sheet revenant_embedContent];
        [sheet revenant_setOffset:[sheet revenant_dismissOffset]];
    }
    [sheet revenant_animateToOffset:presenting ? [sheet revenant_selectedOffset] : [sheet revenant_dismissOffset] velocity:0 completion:^{
        [context completeTransition:![context transitionWasCancelled]];
    }];
}

@end

static void revenant_sheet_apply_stack(RevenantSheetLayoutInfo *node)
{
    for (; node; node = node.child) {
        if (node.root) {
            UIView *view = node.view;
            CGFloat radius, bottom;
            [node getTopCornerRadius:&radius bottomCornerRadius:&bottom];
            view.transform = CGAffineTransformConcat(node.savedTransform, [node transform]);
            view.layer.cornerRadius = radius > 0 ? radius : node.savedCornerRadius;
            view.layer.masksToBounds = radius > 0 || node.savedMasksToBounds;
        } else {
            [node.sheet revenant_applyLayout];
        }
    }
}

@implementation UISheetPresentationController {
    UIView *_sourceView;
    BOOL _prefersEdgeAttachedInCompactHeight;
    BOOL _widthFollowsPreferredContentSizeWhenEdgeAttached;
    BOOL _prefersGrabberVisible;
    BOOL _prefersScrollingExpandsWhenScrolledToEdge;
    CGFloat _preferredCornerRadius;
    NSArray *_detents;
    NSString *_selectedDetentIdentifier;
    NSString *_largestUndimmedDetentIdentifier;

    RevenantSheetLayoutInfo *_layout;
    RevenantSheetLayoutInfo *_rootLayout;
    RevenantSheetView *_sheetView;
    UIView *_dimmingView;
    RevenantSheetView *_confinedDimmingView;
    NSArray *_resolvedOffsets;
    NSArray *_resolvedIdentifiers;
    CGRect _resolvedBounds;
    NSInteger _changing;
    UIViewPropertyAnimator *_animator;
    RevenantSheetAnimator *_transitionAnimator;
    UIPanGestureRecognizer *_pan;
    CGFloat _dragStart;
    BOOL _dismissalDecided;
    BOOL _dismissible;
    BOOL _attemptSent;
    BOOL _interactiveDismissal;
    BOOL _userDismissed;
    id<UIViewControllerContextTransitioning> _dismissalContext;
    UIScrollView *_trackedScrollView;
    CFAbsoluteTime _lastPanEnd;
    CGRect _keyboardFrame;
    BOOL _keyboardShown;
    BOOL _firstResponderRequiresKeyboard;
    BOOL _keyboardAdjusted;
}

@dynamic delegate;

- (instancetype)initWithPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting
{
    if ((self = [super initWithPresentedViewController:presented presentingViewController:presenting])) {
        _preferredCornerRadius = UISheetPresentationControllerAutomaticDimension;
        _prefersScrollingExpandsWhenScrolledToEdge = YES;
        _detents = @[ [UISheetPresentationControllerDetent largeDetent] ];
        _layout = [[RevenantSheetLayoutInfo alloc] init];
        _layout.sheet = self;
        _keyboardFrame = CGRectNull;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Properties

- (UIView *)sourceView { return _sourceView; }
- (void)setSourceView:(UIView *)sourceView { _sourceView = sourceView; }
- (BOOL)prefersEdgeAttachedInCompactHeight { return _prefersEdgeAttachedInCompactHeight; }
- (BOOL)widthFollowsPreferredContentSizeWhenEdgeAttached { return _widthFollowsPreferredContentSizeWhenEdgeAttached; }
- (BOOL)prefersGrabberVisible { return _prefersGrabberVisible; }
- (CGFloat)preferredCornerRadius { return _preferredCornerRadius; }
- (NSArray *)detents { return _detents; }
- (NSString *)selectedDetentIdentifier { return _selectedDetentIdentifier; }
- (NSString *)largestUndimmedDetentIdentifier { return _largestUndimmedDetentIdentifier; }
- (BOOL)prefersScrollingExpandsWhenScrolledToEdge { return _prefersScrollingExpandsWhenScrolledToEdge; }
- (void)setPrefersScrollingExpandsWhenScrolledToEdge:(BOOL)value { _prefersScrollingExpandsWhenScrolledToEdge = value; }

- (void)setPrefersEdgeAttachedInCompactHeight:(BOOL)value
{
    _prefersEdgeAttachedInCompactHeight = value;
    [self revenant_invalidateDetents];
}

- (void)setWidthFollowsPreferredContentSizeWhenEdgeAttached:(BOOL)value
{
    _widthFollowsPreferredContentSizeWhenEdgeAttached = value;
    [self revenant_invalidateDetents];
}

- (void)setPrefersGrabberVisible:(BOOL)value
{
    _prefersGrabberVisible = value;
    [self revenant_changed];
}

- (void)setPreferredCornerRadius:(CGFloat)value
{
    _preferredCornerRadius = value;
    [self revenant_changed];
}

- (void)setDetents:(NSArray *)detents
{
    _detents = [detents copy];
    [self revenant_invalidateDetents];
}

- (void)setSelectedDetentIdentifier:(NSString *)identifier
{
    _selectedDetentIdentifier = [identifier copy];
    [self revenant_moveToSelectedDetent];
}

- (void)setLargestUndimmedDetentIdentifier:(NSString *)identifier
{
    _largestUndimmedDetentIdentifier = [identifier copy];
    _resolvedOffsets = nil;
    [self revenant_changed];
}

- (void)animateChanges:(void (NS_NOESCAPE ^)(void))changes
{
    _changing++;
    if (changes)
        changes();
    _changing--;
    if (_changing == 0 && self.containerView)
        [self revenant_animateToOffset:[self revenant_selectedOffset] velocity:0 completion:nil];
}

- (void)revenant_invalidateDetents
{
    _resolvedOffsets = nil;
    _resolvedIdentifiers = nil;
    [self revenant_moveToSelectedDetent];
}

- (void)revenant_changed
{
    if (_changing == 0 && self.containerView)
        [self revenant_layoutStack];
}

- (void)revenant_moveToSelectedDetent
{
    if (_changing == 0 && self.containerView && !_animator) {
        _layout.offset = [self revenant_selectedOffset];
        [self revenant_layoutStack];
    }
}

#pragma mark Presentation

- (BOOL)shouldPresentInFullscreen
{
    return YES;
}

- (BOOL)shouldRemovePresentersView
{
    return NO;
}

- (UIView *)presentedView
{
    return _sheetView ?: [super presentedView];
}

- (CGRect)frameOfPresentedViewInContainerView
{
    if (!self.containerView)
        return CGRectZero;
    [self revenant_updateLayoutInputs];
    CGFloat offset = _layout.offset;
    _layout.offset = [self revenant_selectedOffset];
    CGRect frame = [_layout untransformedFrame];
    _layout.offset = offset;
    return frame;
}

- (id<UIViewControllerAnimatedTransitioning>)revenant_transitionAnimator
{
    if (!_transitionAnimator) {
        _transitionAnimator = [[RevenantSheetAnimator alloc] init];
        _transitionAnimator.sheet = self;
    }
    return _transitionAnimator;
}

- (void)presentationTransitionWillBegin
{
    [super presentationTransitionWillBegin];
    UIView *container = self.containerView;
    _layout.container = container;
    _layout.presented = YES;

    _dimmingView = [[UIView alloc] initWithFrame:container.bounds];
    _dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_dimmingView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_dimmingTapped:)]];
    [container addSubview:_dimmingView];
    _confinedDimmingView = [[RevenantSheetView alloc] initWithFrame:CGRectZero];
    _confinedDimmingView.hidden = YES;
    [_confinedDimmingView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_dimmingTapped:)]];
    [container addSubview:_confinedDimmingView];

    _sheetView = [[RevenantSheetView alloc] initWithFrame:CGRectZero];
    _sheetView.layer.shadowRadius = 2;
    _sheetView.layer.shadowOffset = CGSizeZero;
    _sheetView.layer.shadowColor = revenant_sheet_dimming_color(container.traitCollection).CGColor;
    _layout.view = _sheetView;
    _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_handlePan:)];
    _pan.enabled = NO;
    _pan.delegate = self;
    [_sheetView addGestureRecognizer:_pan];
    [_sheetView.grabber addTarget:self action:@selector(revenant_grabberTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:_sheetView];
    [self revenant_updateLayoutInputs];
    _layout.offset = [self revenant_dismissOffset];
    [self revenant_layoutStack];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(revenant_keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(revenant_keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [center addObserver:self selector:@selector(revenant_keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)presentationTransitionDidEnd:(BOOL)completed
{
    [super presentationTransitionDidEnd:completed];
    if (!completed) {
        [self revenant_tearDownRemovingViews:YES];
        return;
    }
    [self revenant_linkParent];
    [self revenant_embedContent];
    _pan.enabled = YES;
    if (!_animator) {
        _layout.offset = [self revenant_selectedOffset];
        [self revenant_layoutStack];
    }
}

- (void)dismissalTransitionWillBegin
{
    [super dismissalTransitionWillBegin];
    _pan.enabled = _interactiveDismissal;
}

- (void)dismissalTransitionDidEnd:(BOOL)completed
{
    [super dismissalTransitionDidEnd:completed];
    _interactiveDismissal = NO;
    _dismissalContext = nil;
    _pan.enabled = YES;
    if (!completed)
        return;
    [self revenant_tearDownRemovingViews:NO];
    if (_userDismissed) {
        _userDismissed = NO;
        __weak UISheetPresentationController *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            UISheetPresentationController *strongSelf = weakSelf;
            id<UISheetPresentationControllerDelegate> delegate = strongSelf.delegate;
            if (strongSelf && [delegate respondsToSelector:@selector(presentationControllerDidDismiss:)])
                [delegate presentationControllerDidDismiss:strongSelf];
        });
    }
    UIPresentationController *sheet = self;
    [self.presentedViewController revenant_sheetDidDismiss:self];
    dispatch_async(dispatch_get_main_queue(), ^{
        (void)sheet;
    });
}

- (void)containerViewWillLayoutSubviews
{
    [super containerViewWillLayoutSubviews];
    if (!CGRectEqualToRect(self.containerView.bounds, _resolvedBounds))
        [self revenant_invalidateDetents];
}

- (UIViewController *)presentingViewController
{
    return [super presentingViewController] ?: self.presentedViewController.presentingViewController;
}

- (void)revenant_linkParent
{
    if (_layout.parent || !self.containerView)
        return;
    UIViewController *top = self.presentingViewController;
    while (top.parentViewController)
        top = top.parentViewController;
    UIPresentationController *parent = revenant_presentation_controller_of(top);
    if ([parent isKindOfClass:[UISheetPresentationController class]] && parent.containerView) {
        RevenantSheetLayoutInfo *parentLayout = ((UISheetPresentationController *)parent)->_layout;
        _layout.parent = parentLayout;
        parentLayout.child = _layout;
        return;
    }
    UIWindow *window = top.view.window;
    if (parent || !top || window.rootViewController != top)
        return;
    UIView *rootView = top.view;
    _rootLayout = [[RevenantSheetLayoutInfo alloc] init];
    _rootLayout.root = YES;
    _rootLayout.presented = YES;
    _rootLayout.container = self.containerView;
    _rootLayout.view = rootView;
    _rootLayout.savedTransform = rootView.transform;
    _rootLayout.savedCornerRadius = rootView.layer.cornerRadius;
    _rootLayout.savedMasksToBounds = rootView.layer.masksToBounds;
    rootView.transform = CGAffineTransformIdentity;
    _rootLayout.rootFrame = [self.containerView convertRect:rootView.frame fromView:rootView.superview];
    rootView.transform = _rootLayout.savedTransform;
    _rootLayout.child = _layout;
    _layout.parent = _rootLayout;
}

- (void)revenant_tearDownRemovingViews:(BOOL)removesViews
{
    [_animator stopAnimation:YES];
    _animator = nil;
    RevenantSheetLayoutInfo *parent = _layout.parent;
    _layout.presented = NO;
    if (parent.child == _layout)
        parent.child = nil;
    _layout.parent = nil;
    if (_rootLayout) {
        UIView *rootView = _rootLayout.view;
        rootView.transform = _rootLayout.savedTransform;
        rootView.layer.cornerRadius = _rootLayout.savedCornerRadius;
        rootView.layer.masksToBounds = _rootLayout.savedMasksToBounds;
        _rootLayout = nil;
    } else if (parent) {
        RevenantSheetLayoutInfo *bottom = parent;
        while (bottom.parent)
            bottom = bottom.parent;
        revenant_sheet_apply_stack(bottom);
    }
    [_dimmingView removeFromSuperview];
    _dimmingView = nil;
    [_confinedDimmingView removeFromSuperview];
    _confinedDimmingView = nil;
    UIView *content = self.presentedViewController.view;
    if (removesViews && content.superview == _sheetView.clippingView)
        [content removeFromSuperview];
    [_sheetView removeGestureRecognizer:_pan];
    _pan = nil;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [center removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [center removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    _keyboardFrame = CGRectNull;
    _keyboardShown = NO;
    if (removesViews)
        [_sheetView removeFromSuperview];
    _sheetView = nil;
    _layout.view = nil;
    _layout.container = nil;
    _resolvedOffsets = nil;
    _resolvedIdentifiers = nil;
}

- (void)revenant_embedContent
{
    UIView *content = self.presentedViewController.view;
    if (!_sheetView || content.superview == _sheetView.clippingView)
        return;
    [content removeFromSuperview];
    content.transform = CGAffineTransformIdentity;
    content.frame = _sheetView.clippingView.bounds;
    content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_sheetView.clippingView addSubview:content];
}

#pragma mark Detents and layout

- (void)revenant_updateLayoutInputs
{
    _layout.container = self.containerView;
    _layout.edgeAttachedInCompactHeight = _prefersEdgeAttachedInCompactHeight;
    _layout.widthFollowsPreferredContentSize = _widthFollowsPreferredContentSizeWhenEdgeAttached;
    _layout.preferredWidth = self.presentedViewController.preferredContentSize.width;
    _layout.preferredCornerRadius = _preferredCornerRadius;
    _layout.wantsGrabber = _prefersGrabberVisible;
    if (!_resolvedOffsets)
        [self revenant_resolveDetents];
    _layout.detentOffsets = _resolvedOffsets;
}

- (void)revenant_resolveDetents
{
    UIView *container = self.containerView;
    RevenantSheetDetentContext *context = [[RevenantSheetDetentContext alloc] initWithTraitCollection:container.traitCollection maximumDetentValue:[_layout maximumDetentValue] containerBounds:container.bounds];
    NSMutableArray *entries = [NSMutableArray array];
    for (UISheetPresentationControllerDetent *detent in _detents) {
        CGFloat value = [detent revenant_resolvedValueInContext:context];
        if (value == CGFLOAT_MAX)
            continue;
        [entries addObject:@[ @([_layout offsetForDetentValue:value]), [detent revenant_identifier] ]];
    }
    [entries sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
        return [a[0] compare:b[0]];
    }];
    NSMutableArray *offsets = [NSMutableArray array], *identifiers = [NSMutableArray array];
    for (NSArray *entry in entries) {
        [offsets addObject:entry[0]];
        [identifiers addObject:entry[1]];
    }
    NSUInteger dimming = identifiers.count ? identifiers.count - 1 : NSNotFound;
    if (_largestUndimmedDetentIdentifier) {
        NSUInteger undimmed = [identifiers indexOfObject:_largestUndimmedDetentIdentifier];
        if (undimmed != NSNotFound)
            dimming = undimmed == 0 ? NSNotFound : undimmed - 1;
    }
    CGRect keyboard = CGRectIntersection(_keyboardFrame, [_layout fullHeightFrame]);
    _keyboardAdjusted = _firstResponderRequiresKeyboard && offsets.count && !CGRectIsNull(keyboard)
        && revenant_sheet_first_responder_in(self.presentedViewController.view);
    if (_keyboardAdjusted) {
        CGFloat large = [_layout offsetForDetentValue:[[UISheetPresentationControllerDetent largeDetent] revenant_resolvedValueInContext:context]];
        CGFloat first = [offsets[0] doubleValue];
        if (first > large) {
            [offsets insertObject:@(MAX(first - CGRectGetHeight(keyboard), large)) atIndex:0];
            [identifiers insertObject:[NSNull null] atIndex:0];
            dimming = dimming == NSNotFound ? 0 : dimming + 1;
        }
    }
    _resolvedOffsets = offsets;
    _resolvedIdentifiers = identifiers;
    _layout.dimmingIndex = dimming;
    _resolvedBounds = container.bounds;
}

- (CGFloat)revenant_dismissOffset
{
    return [_layout dismissOffset];
}

- (CGFloat)revenant_selectedOffset
{
    [self revenant_updateLayoutInputs];
    if (!_resolvedOffsets.count)
        return CGRectGetMinY([_layout stackAlignmentFrame]);
    return [_resolvedOffsets[[self revenant_indexOfCurrentDetent]] doubleValue];
}

- (NSUInteger)revenant_indexOfCurrentDetent
{
    if (_keyboardAdjusted)
        return 0;
    NSUInteger index = _selectedDetentIdentifier ? [_resolvedIdentifiers indexOfObject:_selectedDetentIdentifier] : NSNotFound;
    return index != NSNotFound ? index : _resolvedOffsets.count - 1;
}

- (void)revenant_setOffset:(CGFloat)offset
{
    _layout.offset = offset;
    [self revenant_layoutStack];
}

- (void)revenant_layoutStack
{
    if (!self.containerView)
        return;
    [self revenant_updateLayoutInputs];
    RevenantSheetLayoutInfo *bottom = _layout;
    while (bottom.parent)
        bottom = bottom.parent;
    revenant_sheet_apply_stack(bottom);
}

- (void)revenant_applyLayout
{
    CGRect frame = [_layout untransformedFrame];
    _sheetView.bounds = CGRectMake(0, 0, CGRectGetWidth(frame), CGRectGetHeight(frame));
    _sheetView.center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    _sheetView.transform = [_layout transform];
    CGFloat top, bottom;
    [_layout getTopCornerRadius:&top bottomCornerRadius:&bottom];
    [_sheetView setTopCornerRadius:top bottomCornerRadius:bottom];
    _sheetView.grabber.hidden = !_prefersGrabberVisible;
    _sheetView.grabber.alpha = [_layout grabberAlpha];
    _sheetView.layer.shadowOpacity = [_layout shadowOpacity];
    [_sheetView setMagicShadowAlpha:[_layout magicShadowOpacity]];
    UITraitCollection *traits = self.containerView.traitCollection;
    _sheetView.grabber.backgroundColor = [revenant_sheet_grabber_color() resolvedColorWithTraitCollection:traits];

    BOOL enabled = [_layout percentDimmedFromOffset] > 0;
    _dimmingView.frame = self.containerView.bounds;
    _dimmingView.backgroundColor = revenant_sheet_dimming_background(traits, [_layout percentDimmed], 0);
    _dimmingView.userInteractionEnabled = enabled;

    RevenantSheetLayoutInfo *parent = _layout.parent;
    _confinedDimmingView.hidden = !parent;
    _confinedDimmingView.userInteractionEnabled = enabled;
    if (parent) {
        CGRect under = [parent untransformedFrame];
        _confinedDimmingView.bounds = CGRectMake(0, 0, CGRectGetWidth(under), CGRectGetHeight(under));
        _confinedDimmingView.center = CGPointMake(CGRectGetMidX(under), CGRectGetMidY(under));
        _confinedDimmingView.transform = [parent transform];
        [parent getTopCornerRadius:&top bottomCornerRadius:&bottom];
        [_confinedDimmingView setTopCornerRadius:top bottomCornerRadius:bottom];
        UITraitCollection *parentTraits = parent.root ? parent.view.traitCollection : parent.sheet.presentedViewController.traitCollection;
        CGFloat lightened = parentTraits.userInterfaceStyle == UIUserInterfaceStyleDark && parentTraits.userInterfaceLevel == UIUserInterfaceLevelBase ? 1 - [parent percentFullScreen] : 0;
        _confinedDimmingView.clippingView.backgroundColor = revenant_sheet_dimming_background(traits, [_layout confinedPercentDimmed], lightened);
    }
}

- (BOOL)revenant_dimmingIgnoresTouches
{
    if (_layout.offset > [_layout margins].top)
        return _pan.state == UIGestureRecognizerStateBegan || _pan.state == UIGestureRecognizerStateChanged;
    return YES;
}

- (void)revenant_dimmingTapped:(UITapGestureRecognizer *)tap
{
    if (tap.state != UIGestureRecognizerStateEnded || [self revenant_dimmingIgnoresTouches] || _interactiveDismissal)
        return;
    [self revenant_dismissFromGrabberOrDimmingViewIfPossible];
}

- (void)revenant_dismissFromGrabberOrDimmingViewIfPossible
{
    if ([self revenant_shouldDismiss]) {
        _userDismissed = YES;
        id<UISheetPresentationControllerDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(presentationControllerWillDismiss:)])
            [delegate presentationControllerWillDismiss:self];
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    NSString *undimmed = _largestUndimmedDetentIdentifier;
    if (!undimmed)
        return;
    [self animateChanges:^{
        self.selectedDetentIdentifier = undimmed;
    }];
    id<UISheetPresentationControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(sheetPresentationControllerDidChangeSelectedDetentIdentifier:)])
        [delegate sheetPresentationControllerDidChangeSelectedDetentIdentifier:self];
}

- (void)revenant_grabberTapped
{
    if (_interactiveDismissal || !_resolvedOffsets.count)
        return;
    if (_keyboardAdjusted) {
        [self.presentedViewController.view endEditing:YES];
        return;
    }
    NSUInteger count = _resolvedOffsets.count, current = [self revenant_indexOfCurrentDetent];
    NSUInteger target = (count + current - 1) % count;
    if (target == current) {
        [self revenant_dismissFromGrabberOrDimmingViewIfPossible];
        return;
    }
    NSString *identifier = _resolvedIdentifiers[target];
    [self animateChanges:^{
        self.selectedDetentIdentifier = identifier;
    }];
    id<UISheetPresentationControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(sheetPresentationControllerDidChangeSelectedDetentIdentifier:)])
        [delegate sheetPresentationControllerDidChangeSelectedDetentIdentifier:self];
}

#pragma mark The keyboard

- (void)revenant_keyboardWillShow:(NSNotification *)notification
{
    _keyboardShown = YES;
    [self revenant_keyboardChanged:notification hiding:NO];
}

- (void)revenant_keyboardWillHide:(NSNotification *)notification
{
    _keyboardShown = NO;
    [self revenant_keyboardChanged:notification hiding:YES];
}

- (void)revenant_keyboardWillChangeFrame:(NSNotification *)notification
{
    if (_keyboardShown)
        [self revenant_keyboardChanged:notification hiding:NO];
}

- (void)revenant_keyboardChanged:(NSNotification *)notification hiding:(BOOL)hiding
{
    UIView *container = self.containerView;
    if (!container)
        return;
    NSDictionary *info = notification.userInfo;
    UIWindow *window = container.window;
    CGRect end = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _keyboardFrame = hiding || !window ? CGRectNull : [container convertRect:[window convertRect:end fromWindow:nil] fromView:window];
    UIResponder *responder = revenant_sheet_first_responder(window);
    _firstResponderRequiresKeyboard = [responder conformsToProtocol:@protocol(UIKeyInput)] && (![responder respondsToSelector:@selector(isEditable)] || [(id)responder isEditable]);
    _resolvedOffsets = nil;
    if (_animator || _interactiveDismissal || _pan.state == UIGestureRecognizerStateBegan || _pan.state == UIGestureRecognizerStateChanged)
        return;
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [info[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptions)curve << 16 animations:^{
        [self revenant_updateLayoutInputs];
        self->_layout.offset = [self revenant_selectedOffset];
        [self revenant_layoutStack];
    } completion:nil];
}

- (BOOL)revenant_containerIgnoresDirectTouches
{
    return YES;
}

#pragma mark The drag

- (BOOL)revenant_shouldDismiss
{
    UIViewController *presented = self.presentedViewController;
    if (presented.presentedViewController || presented.isModalInPresentation)
        return NO;
    id<UISheetPresentationControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(presentationControllerShouldDismiss:)])
        return [delegate presentationControllerShouldDismiss:self];
    return YES;
}

- (CGFloat)revenant_displayedOffset
{
    CALayer *layer = (CALayer *)_sheetView.layer.presentationLayer ?: _sheetView.layer;
    return layer.position.y - CGRectGetHeight(_sheetView.bounds) / 2;
}

- (CGFloat)revenant_bottomExtent
{
    return MIN(MAX(revenant_sheet_bottom_extent_fraction * CGRectGetHeight([_layout fullHeightFrame]), 0), revenant_sheet_bottom_extent);
}

- (CGFloat)revenant_constrainedOffset:(CGFloat)offset
{
    CGFloat top = [_resolvedOffsets.firstObject doubleValue], bottom = [_resolvedOffsets.lastObject doubleValue];
    if (offset < top) {
        CGFloat extent = MIN(MAX(CGRectGetMinY(self.containerView.bounds) + top - self.containerView.safeAreaInsets.top, 0), revenant_sheet_top_extent);
        return top - revenant_sheet_rubber_band(top - offset, extent);
    }
    if (offset > bottom && !(_dismissalDecided && _dismissible))
        return bottom + revenant_sheet_rubber_band(offset - bottom, [self revenant_bottomExtent]);
    return offset;
}

- (void)revenant_handlePan:(UIPanGestureRecognizer *)pan
{
    UIView *container = self.containerView;
    if (!container || !_resolvedOffsets.count)
        return;
    switch (pan.state) {
    case UIGestureRecognizerStateBegan: {
        CGFloat shown = [self revenant_displayedOffset];
        [_animator stopAnimation:YES];
        _animator = nil;
        [self revenant_setOffset:shown];
        _dragStart = shown;
        _dismissalDecided = _interactiveDismissal;
        _dismissible = _interactiveDismissal;
        _attemptSent = NO;
        break;
    }
    case UIGestureRecognizerStateChanged: {
        CGFloat unconstrained = _dragStart + [pan translationInView:container].y;
        CGFloat bottom = [_resolvedOffsets.lastObject doubleValue];
        if (unconstrained > bottom && !_dismissalDecided) {
            _dismissalDecided = YES;
            _dismissible = [self revenant_shouldDismiss];
            if (_dismissible)
                [self revenant_beginInteractiveDismissal];
        }
        CGFloat offset = [self revenant_constrainedOffset:unconstrained];
        if (_dismissalDecided && !_dismissible && !_attemptSent && offset - bottom > 0.25 * [self revenant_bottomExtent]) {
            _attemptSent = YES;
            __weak UISheetPresentationController *weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                UISheetPresentationController *strongSelf = weakSelf;
                id<UISheetPresentationControllerDelegate> delegate = strongSelf.delegate;
                if (strongSelf && [delegate respondsToSelector:@selector(presentationControllerDidAttemptToDismiss:)])
                    [delegate presentationControllerDidAttemptToDismiss:strongSelf];
            });
        }
        [self revenant_holdTrackedScrollView];
        [self revenant_setOffset:offset];
        break;
    }
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed: {
        CGFloat unconstrained = _dragStart + [pan translationInView:container].y;
        CGFloat velocity = pan.state == UIGestureRecognizerStateEnded ? [pan velocityInView:container].y : 0;
        [self revenant_holdTrackedScrollView];
        _trackedScrollView = nil;
        _lastPanEnd = CFAbsoluteTimeGetCurrent();
        [self revenant_endDragAt:unconstrained velocity:velocity];
        break;
    }
    default:
        break;
    }
}

- (BOOL)revenant_takesPanFromScrollView:(UIScrollView *)scrollView velocity:(CGPoint)velocity
{
    UIEdgeInsets inset = scrollView.adjustedContentInset;
    if (scrollView.contentOffset.y > -inset.top)
        return NO;
    if ([scrollView respondsToSelector:@selector(refreshControl)] && [scrollView valueForKey:@"refreshControl"])
        return NO;
    if (scrollView.contentSize.width > CGRectGetWidth(scrollView.bounds) - inset.left - inset.right)
        return NO;
    if ([scrollView respondsToSelector:@selector(keyboardDismissMode)] && scrollView.keyboardDismissMode == UIScrollViewKeyboardDismissModeInteractive && revenant_sheet_first_responder_in(scrollView))
        return NO;
    if (CFAbsoluteTimeGetCurrent() - _lastPanEnd < revenant_sheet_swipe_interval && !_animator)
        return NO;
    if (velocity.y > 0)
        return YES;
    return _prefersScrollingExpandsWhenScrolledToEdge && _layout.offset > [_resolvedOffsets.firstObject doubleValue];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture
{
    if (gesture != _pan)
        return YES;
    UIView *hit = [_sheetView hitTest:[gesture locationInView:_sheetView] withEvent:nil];
    UIScrollView *scrollView = nil;
    for (UIView *view = hit; view && view != _sheetView; view = view.superview)
        if ([view isKindOfClass:[UIScrollView class]] && ((UIScrollView *)view).scrollEnabled) {
            scrollView = (UIScrollView *)view;
            break;
        }
    _trackedScrollView = nil;
    if (!scrollView)
        return YES;
    if (![self revenant_takesPanFromScrollView:scrollView velocity:[_pan velocityInView:_sheetView]])
        return NO;
    _trackedScrollView = scrollView;
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    return gesture == _pan && [other.view isKindOfClass:[UIScrollView class]] && [other.view isDescendantOfView:_sheetView];
}

- (void)revenant_holdTrackedScrollView
{
    UIScrollView *scrollView = _trackedScrollView;
    if (scrollView)
        scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, -scrollView.adjustedContentInset.top);
}

static NSUInteger revenant_sheet_closest(NSArray *offsets, CGFloat offset)
{
    NSUInteger best = 0;
    for (NSUInteger i = 1; i < offsets.count; i++)
        if (fabs([offsets[i] doubleValue] - offset) < fabs([offsets[best] doubleValue] - offset))
            best = i;
    return best;
}

- (void)revenant_endDragAt:(CGFloat)unconstrained velocity:(CGFloat)velocity
{
    NSMutableArray *regions = [_resolvedOffsets mutableCopy];
    BOOL dismissible = _interactiveDismissal;
    if (dismissible)
        [regions addObject:@([self revenant_dismissOffset])];
    CGFloat effective = revenant_sheet_effective_velocity(velocity);
    CGFloat projected = unconstrained + effective * (revenant_sheet_deceleration_rate / (1 - revenant_sheet_deceleration_rate)) / 1000;
    NSUInteger c = revenant_sheet_closest(regions, unconstrained), p = revenant_sheet_closest(regions, projected);
    BOOL fast = fabs(velocity) >= revenant_sheet_flick_speed;
    NSInteger step = regions.count > 1 && [regions[0] doubleValue] > [regions[1] doubleValue] ? -1 : 1;
    NSInteger index = (NSInteger)p;
    if (fast && c == p && (velocity < 0) == (unconstrained < [regions[c] doubleValue]))
        index = MIN(MAX((NSInteger)c + (velocity < 0 ? -step : step), 0), (NSInteger)regions.count - 1);
    CGFloat damping = fast ? revenant_sheet_spring_damping_fast : revenant_sheet_spring_damping;
    CGFloat target = [regions[index] doubleValue];
    if (dismissible && (NSUInteger)index == regions.count - 1) {
        id<UIViewControllerContextTransitioning> context = _dismissalContext;
        _userDismissed = YES;
        [self revenant_animateToOffset:target velocity:velocity damping:damping completion:^{
            [context completeTransition:YES];
        }];
        return;
    }
    id identifier = _resolvedIdentifiers[index];
    NSString *before = _selectedDetentIdentifier;
    BOOL keyboardDetent = identifier == [NSNull null];
    BOOL wasThere = keyboardDetent || [identifier isEqualToString:before] || (![_resolvedIdentifiers containsObject:before ?: @""] && (NSUInteger)index == _resolvedIdentifiers.count - 1);
    if (!keyboardDetent)
        _selectedDetentIdentifier = [identifier copy];
    id<UIViewControllerContextTransitioning> context = _interactiveDismissal ? _dismissalContext : nil;
    [self revenant_animateToOffset:target velocity:velocity damping:damping completion:^{
        if (context) {
            [context cancelInteractiveTransition];
            [context completeTransition:NO];
        }
    }];
    id<UISheetPresentationControllerDelegate> delegate = self.delegate;
    if (!wasThere && [delegate respondsToSelector:@selector(sheetPresentationControllerDidChangeSelectedDetentIdentifier:)])
        [delegate sheetPresentationControllerDidChangeSelectedDetentIdentifier:self];
}

- (void)revenant_beginInteractiveDismissal
{
    _interactiveDismissal = YES;
    _userDismissed = NO;
    id<UISheetPresentationControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(presentationControllerWillDismiss:)])
        [delegate presentationControllerWillDismiss:self];
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)revenant_takeInteractiveDismissal:(id<UIViewControllerContextTransitioning>)context
{
    if (!_interactiveDismissal)
        return NO;
    _dismissalContext = context;
    return YES;
}

- (void)revenant_animateToOffset:(CGFloat)offset velocity:(CGFloat)velocity completion:(void (^)(void))completion
{
    [self revenant_animateToOffset:offset velocity:velocity damping:revenant_sheet_spring_damping completion:completion];
}

- (void)revenant_animateToOffset:(CGFloat)offset velocity:(CGFloat)velocity damping:(CGFloat)damping completion:(void (^)(void))completion
{
    [_animator stopAnimation:YES];
    CGFloat omega = 2 * M_PI / revenant_sheet_spring_response;
    CGFloat distance = offset - _layout.offset;
    UISpringTimingParameters *spring = [[UISpringTimingParameters alloc] initWithMass:1 stiffness:omega * omega damping:2 * damping * omega initialVelocity:CGVectorMake(0, distance != 0 ? velocity / distance : 0)];
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:revenant_sheet_transition_duration timingParameters:spring];
    __weak UISheetPresentationController *weakSelf = self;
    [animator addAnimations:^{
        [weakSelf revenant_setOffset:offset];
    }];
    [animator addCompletion:^(UIViewAnimatingPosition position) {
        UISheetPresentationController *strongSelf = weakSelf;
        if (strongSelf && strongSelf->_animator == animator)
            strongSelf->_animator = nil;
        if (completion)
            completion();
    }];
    _animator = animator;
    [animator startAnimation];
}

@end

@interface UIViewController (RevenantSheetPresentation)
@end

@implementation UIViewController (RevenantSheetPresentation)

- (UISheetPresentationController *)sheetPresentationController
{
    UIPresentationController *current = revenant_presentation_controller_of(self);
    if ([current isKindOfClass:[UISheetPresentationController class]] && (current.containerView || revenant_sheet_style(self.modalPresentationStyle)))
        return (UISheetPresentationController *)current;
    if (current || !revenant_sheet_style(self.modalPresentationStyle))
        return nil;
    UISheetPresentationController *sheet = [[UISheetPresentationController alloc] initWithPresentedViewController:self presentingViewController:nil];
    revenant_set_presentation_controller(self, sheet);
    return sheet;
}

@end
