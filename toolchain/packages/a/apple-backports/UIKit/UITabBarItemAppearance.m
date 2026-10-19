#import "RevenantBarAppearance.h"

static NSString *const RevenantTitle = @"title";
static NSString *const RevenantTitleOffset = @"titleOffset";
static NSString *const RevenantIcon = @"icon";
static NSString *const RevenantBadgeOffset = @"badgeOffset";
static NSString *const RevenantBadgeBackground = @"badgeBackground";
static NSString *const RevenantBadgeTitle = @"badgeTitle";
static NSString *const RevenantBadgeTitleOffset = @"badgeTitleOffset";

static NSDictionary *revenant_item_classes(void)
{
    return @{RevenantTitle: [NSDictionary class], RevenantTitleOffset: [NSArray class], RevenantIcon: [UIColor class], RevenantBadgeOffset: [NSArray class],
             RevenantBadgeBackground: [UIColor class], RevenantBadgeTitle: [NSDictionary class], RevenantBadgeTitleOffset: [NSArray class]};
}

static id revenant_item_resolve(NSInteger style, NSArray *customs, NSInteger state, NSString *key)
{
    NSDictionary *own = customs[state], *normal = customs[0];
    if ([key isEqual:RevenantTitle]) {
        CGFloat sizes[] = {10, 13, 12};
        NSDictionary *base = style < 3 ? @{NSFontAttributeName: revenant_font(sizes[style], state == 1 ? UIFontWeightSemibold : (style == 0 ? UIFontWeightMedium : UIFontWeightRegular))} : @{};
        NSDictionary *carried = state ? revenant_attributes_carried(normal[key], state != 1, NO) : @{};
        NSDictionary *merged = revenant_attributes_merge(revenant_attributes_merge(base, carried), own[key]);
        return merged.count ? merged : nil;
    }
    if ([key isEqual:RevenantBadgeTitle]) {
        CGFloat sizes[] = {13, 13, 10, 10, 28};
        NSDictionary *base = @{NSForegroundColorAttributeName: revenant_white_colour(), NSFontAttributeName: revenant_font(sizes[style], style == 2 ? UIFontWeightMedium : UIFontWeightRegular)};
        NSDictionary *carried = state ? revenant_attributes_carried(normal[key], YES, NO) : @{};
        return revenant_attributes_merge(revenant_attributes_merge(base, carried), own[key]);
    }
    if ([key isEqual:RevenantIcon])
        return own[key] ?: ((state == 2 || state == 3) ? normal[key] : nil);
    if ([key isEqual:RevenantBadgeBackground])
        return own[key] ?: (state ? normal[key] : nil) ?: (style >= 3 ? [UIColor colorWithRed:1 green:59.0 / 255 blue:48.0 / 255 alpha:1] : [UIColor colorWithRed:1 green:56.0 / 255 blue:60.0 / 255 alpha:1]);
    return own[key] ?: (state ? normal[key] : nil) ?: revenant_offset_pack(UIOffsetZero);
}

@implementation UITabBarItemStateAppearance {
@private
    __weak UITabBarItemAppearance *_owner;
    NSInteger _state;
    NSMutableDictionary *_custom;
}

- (instancetype)initRevenantWithOwner:(UITabBarItemAppearance *)owner state:(NSInteger)state
{
    if ((self = [super init])) {
        _owner = owner;
        _state = state;
        _custom = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSMutableDictionary *)revenant_custom
{
    return _custom;
}

- (id)revenant_resolve:(NSString *)key
{
    if (_owner)
        return [_owner revenant_resolveState:_state key:key];
    NSMutableArray *customs = [NSMutableArray array];
    for (NSInteger state = 0; state < 4; state++)
        [customs addObject:state == _state ? _custom : @{}];
    return revenant_item_resolve(0, customs, _state, key);
}

- (void)revenant_setValue:(id)value key:(NSString *)key
{
    if (!value)
        [_custom removeObjectForKey:key];
    else if (!revenant_same(value, [self revenant_resolve:key]))
        _custom[key] = value;
}

- (void)revenant_setAttributes:(NSDictionary *)attributes key:(NSString *)key
{
    if (!attributes.count)
        [_custom removeObjectForKey:key];
    else if (![attributes isEqual:[self revenant_resolve:key]])
        _custom[key] = [attributes copy];
}

- (NSDictionary *)titleTextAttributes
{
    return [self revenant_resolve:RevenantTitle];
}

- (void)setTitleTextAttributes:(NSDictionary *)titleTextAttributes
{
    [self revenant_setAttributes:titleTextAttributes key:RevenantTitle];
    [_owner revenant_notify];
}

- (UIOffset)titlePositionAdjustment
{
    return revenant_offset_unpack([self revenant_resolve:RevenantTitleOffset]);
}

- (void)setTitlePositionAdjustment:(UIOffset)titlePositionAdjustment
{
    [self revenant_setValue:revenant_offset_pack(titlePositionAdjustment) key:RevenantTitleOffset];
    [_owner revenant_notify];
}

- (UIColor *)iconColor
{
    return [self revenant_resolve:RevenantIcon];
}

- (void)setIconColor:(UIColor *)iconColor
{
    [self revenant_setValue:[iconColor copy] key:RevenantIcon];
    [_owner revenant_notify];
}

- (UIOffset)badgePositionAdjustment
{
    return revenant_offset_unpack([self revenant_resolve:RevenantBadgeOffset]);
}

- (void)setBadgePositionAdjustment:(UIOffset)badgePositionAdjustment
{
    [self revenant_setValue:revenant_offset_pack(badgePositionAdjustment) key:RevenantBadgeOffset];
    [_owner revenant_notify];
}

- (UIColor *)badgeBackgroundColor
{
    return [self revenant_resolve:RevenantBadgeBackground];
}

- (void)setBadgeBackgroundColor:(UIColor *)badgeBackgroundColor
{
    [self revenant_setValue:[badgeBackgroundColor copy] key:RevenantBadgeBackground];
    [_owner revenant_notify];
}

- (NSDictionary *)badgeTextAttributes
{
    return [self revenant_resolve:RevenantBadgeTitle];
}

- (void)setBadgeTextAttributes:(NSDictionary *)badgeTextAttributes
{
    [self revenant_setAttributes:badgeTextAttributes key:RevenantBadgeTitle];
    [_owner revenant_notify];
}

- (UIOffset)badgeTitlePositionAdjustment
{
    return revenant_offset_unpack([self revenant_resolve:RevenantBadgeTitleOffset]);
}

- (void)setBadgeTitlePositionAdjustment:(UIOffset)badgeTitlePositionAdjustment
{
    [self revenant_setValue:revenant_offset_pack(badgeTitlePositionAdjustment) key:RevenantBadgeTitleOffset];
    [_owner revenant_notify];
}

- (NSString *)revenant_text
{
    NSMutableArray *parts = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"titleTextAttributes=%@", revenant_attributes_text(_custom[RevenantTitle])]];
    if (_custom[RevenantTitleOffset])
        [parts addObject:[NSString stringWithFormat:@"titlePositionAdjustment=%@", revenant_offset_text(_custom[RevenantTitleOffset])]];
    [parts addObject:[NSString stringWithFormat:@"iconColor=%@", revenant_text(_custom[RevenantIcon])]];
    if (_custom[RevenantBadgeOffset])
        [parts addObject:[NSString stringWithFormat:@"badgePositionAdjustment=%@", revenant_offset_text(_custom[RevenantBadgeOffset])]];
    [parts addObject:[NSString stringWithFormat:@"badgeBackgroundColor=%@", revenant_text(_custom[RevenantBadgeBackground])]];
    [parts addObject:[NSString stringWithFormat:@"badgeTextAttributes=%@", revenant_attributes_text(_custom[RevenantBadgeTitle])]];
    if (_custom[RevenantBadgeTitleOffset])
        [parts addObject:[NSString stringWithFormat:@"badgeTitlePositionAdjustment=%@", revenant_offset_text(_custom[RevenantBadgeTitleOffset])]];
    return [NSString stringWithFormat:@"(%@)", [parts componentsJoinedByString:@", "]];
}

@end

@implementation UITabBarItemAppearance {
@private
    NSInteger _style;
    NSArray *_states;
    void (^_changeObserver)(void);
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

static void revenant_check_item_style(NSInteger style)
{
    if (style < 0 || style > 4)
        [NSException raise:NSInternalInconsistencyException format:@"Unsupported style %ld", (long)style];
}

- (instancetype)init
{
    return [self initWithStyle:UITabBarItemAppearanceStyleStacked];
}

- (instancetype)initWithStyle:(UITabBarItemAppearanceStyle)style
{
    revenant_check_item_style(style);
    if ((self = [super init]))
        [self revenant_setUpStyle:style];
    return self;
}

- (void)revenant_setUpStyle:(NSInteger)style
{
    _style = style;
    NSMutableArray *states = [NSMutableArray array];
    for (NSInteger state = 0; state < 4; state++)
        [states addObject:[[UITabBarItemStateAppearance alloc] initRevenantWithOwner:self state:state]];
    _states = states;
}

- (instancetype)initRevenantWithStyle:(NSInteger)style
{
    if ((self = [self initWithStyle:UITabBarItemAppearanceStyleStacked]))
        [self revenant_setUpStyle:style];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSInteger style = [coder decodeIntegerForKey:@"style"];
    if ((self = [super init])) {
        [self revenant_setUpStyle:(style >= 0 && style <= 4) ? style : 0];
        NSArray *names = @[@"normal", @"selected", @"disabled", @"focused"];
        for (NSInteger state = 0; state < 4; state++) {
            id packed = [coder decodeObjectOfClasses:revenant_plist_classes() forKey:names[state]];
            [[_states[state] revenant_custom] setDictionary:revenant_sanitised(revenant_plist_unpack(packed), revenant_item_classes(), nil)];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_style forKey:@"style"];
    NSArray *names = @[@"normal", @"selected", @"disabled", @"focused"];
    for (NSInteger state = 0; state < 4; state++)
        [coder encodeObject:revenant_plist_pack([_states[state] revenant_custom]) forKey:names[state]];
}

- (id)copyWithZone:(NSZone *)zone
{
    UITabBarItemAppearance *copy = [[[self class] allocWithZone:zone] initRevenantWithStyle:_style];
    for (NSInteger state = 0; state < 4; state++)
        [[copy->_states[state] revenant_custom] setDictionary:[_states[state] revenant_custom]];
    return copy;
}

- (instancetype)copy
{
    return [self copyWithZone:nil];
}

- (void)configureWithDefaultForStyle:(UITabBarItemAppearanceStyle)style
{
    revenant_check_item_style(style);
    _style = style;
    for (UITabBarItemStateAppearance *state in _states)
        [[state revenant_custom] removeAllObjects];
    [self revenant_notify];
}

- (UITabBarItemStateAppearance *)normal
{
    return _states[0];
}

- (UITabBarItemStateAppearance *)selected
{
    return _states[1];
}

- (UITabBarItemStateAppearance *)disabled
{
    return _states[2];
}

- (UITabBarItemStateAppearance *)focused
{
    return _states[3];
}

- (void)revenant_setChangeObserver:(void (^)(void))observer
{
    _changeObserver = [observer copy];
}

- (void)revenant_notify
{
    if (_changeObserver)
        _changeObserver();
}

- (NSInteger)revenant_style
{
    return _style;
}

- (NSDictionary *)revenant_customOfState:(NSInteger)state
{
    return [_states[state] revenant_custom];
}

- (id)revenant_resolveState:(NSInteger)state key:(NSString *)key
{
    NSMutableArray *customs = [NSMutableArray array];
    for (UITabBarItemStateAppearance *one in _states)
        [customs addObject:[one revenant_custom]];
    return revenant_item_resolve(_style, customs, state, key);
}

- (NSString *)revenant_text
{
    NSArray *styles = @[@"stacked", @"inline", @"compactInline", @"carplay", @"tv"];
    NSMutableString *text = [NSMutableString stringWithFormat:@"baseStyle=%@", styles[_style]];
    NSArray *names = @[@"normal", @"selected", @"disabled", @"focused"];
    for (NSInteger state = 0; state < 4; state++)
        [text appendFormat:@" %@=%@", names[state], [_states[state] revenant_text]];
    return text;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> %@", [self class], self, [self revenant_text]];
}

- (NSArray *)revenant_signature
{
    NSMutableArray *signature = [NSMutableArray arrayWithObject:@(_style)];
    for (UITabBarItemStateAppearance *state in _states) {
        NSMutableDictionary *custom = [NSMutableDictionary dictionaryWithDictionary:[state revenant_custom]];
        for (NSString *key in @[RevenantTitleOffset, RevenantBadgeOffset, RevenantBadgeTitleOffset])
            if ([custom[key] isEqual:revenant_offset_pack(UIOffsetZero)])
                [custom removeObjectForKey:key];
        [signature addObject:custom];
    }
    return signature;
}

- (BOOL)isEqual:(id)object
{
    return object == self || ([object isKindOfClass:[UITabBarItemAppearance class]] && [[self revenant_signature] isEqual:[object revenant_signature]]);
}

- (NSUInteger)hash
{
    return [[self revenant_signature] hash];
}

@end
