#import "CharonBarAppearance.h"

static NSString *const CharonTitle = @"title";
static NSString *const CharonTitleOffset = @"titleOffset";
static NSString *const CharonIcon = @"icon";
static NSString *const CharonBadgeOffset = @"badgeOffset";
static NSString *const CharonBadgeBackground = @"badgeBackground";
static NSString *const CharonBadgeTitle = @"badgeTitle";
static NSString *const CharonBadgeTitleOffset = @"badgeTitleOffset";

static NSDictionary *charon_item_classes(void)
{
    return @{CharonTitle: [NSDictionary class], CharonTitleOffset: [NSArray class], CharonIcon: [UIColor class], CharonBadgeOffset: [NSArray class],
             CharonBadgeBackground: [UIColor class], CharonBadgeTitle: [NSDictionary class], CharonBadgeTitleOffset: [NSArray class]};
}

static id charon_item_resolve(NSInteger style, NSArray *customs, NSInteger state, NSString *key)
{
    NSDictionary *own = customs[state], *normal = customs[0];
    if ([key isEqual:CharonTitle]) {
        CGFloat sizes[] = {10, 13, 12};
        NSDictionary *base = style < 3 ? @{NSFontAttributeName: charon_font(sizes[style], state == 1 ? UIFontWeightSemibold : (style == 0 ? UIFontWeightMedium : UIFontWeightRegular))} : @{};
        NSDictionary *carried = state ? charon_attributes_carried(normal[key], state != 1, NO) : @{};
        NSDictionary *merged = charon_attributes_merge(charon_attributes_merge(base, carried), own[key]);
        return merged.count ? merged : nil;
    }
    if ([key isEqual:CharonBadgeTitle]) {
        CGFloat sizes[] = {13, 13, 10, 10, 28};
        NSDictionary *base = @{NSForegroundColorAttributeName: charon_white_colour(), NSFontAttributeName: charon_font(sizes[style], style == 2 ? UIFontWeightMedium : UIFontWeightRegular)};
        NSDictionary *carried = state ? charon_attributes_carried(normal[key], YES, NO) : @{};
        return charon_attributes_merge(charon_attributes_merge(base, carried), own[key]);
    }
    if ([key isEqual:CharonIcon])
        return own[key] ?: ((state == 2 || state == 3) ? normal[key] : nil);
    if ([key isEqual:CharonBadgeBackground])
        return own[key] ?: (state ? normal[key] : nil) ?: (style >= 3 ? [UIColor colorWithRed:1 green:59.0 / 255 blue:48.0 / 255 alpha:1] : [UIColor colorWithRed:1 green:56.0 / 255 blue:60.0 / 255 alpha:1]);
    return own[key] ?: (state ? normal[key] : nil) ?: charon_offset_pack(UIOffsetZero);
}

@implementation UITabBarItemStateAppearance {
@private
    __weak UITabBarItemAppearance *_owner;
    NSInteger _state;
    NSMutableDictionary *_custom;
}

- (instancetype)initCharonWithOwner:(UITabBarItemAppearance *)owner state:(NSInteger)state
{
    if ((self = [super init])) {
        _owner = owner;
        _state = state;
        _custom = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSMutableDictionary *)charon_custom
{
    return _custom;
}

- (id)charon_resolve:(NSString *)key
{
    if (_owner)
        return [_owner charon_resolveState:_state key:key];
    NSMutableArray *customs = [NSMutableArray array];
    for (NSInteger state = 0; state < 4; state++)
        [customs addObject:state == _state ? _custom : @{}];
    return charon_item_resolve(0, customs, _state, key);
}

- (void)charon_setValue:(id)value key:(NSString *)key
{
    if (!value)
        [_custom removeObjectForKey:key];
    else if (!charon_same(value, [self charon_resolve:key]))
        _custom[key] = value;
}

- (void)charon_setAttributes:(NSDictionary *)attributes key:(NSString *)key
{
    if (!attributes.count)
        [_custom removeObjectForKey:key];
    else if (![attributes isEqual:[self charon_resolve:key]])
        _custom[key] = [attributes copy];
}

- (NSDictionary *)titleTextAttributes
{
    return [self charon_resolve:CharonTitle];
}

- (void)setTitleTextAttributes:(NSDictionary *)titleTextAttributes
{
    [self charon_setAttributes:titleTextAttributes key:CharonTitle];
    [_owner charon_notify];
}

- (UIOffset)titlePositionAdjustment
{
    return charon_offset_unpack([self charon_resolve:CharonTitleOffset]);
}

- (void)setTitlePositionAdjustment:(UIOffset)titlePositionAdjustment
{
    [self charon_setValue:charon_offset_pack(titlePositionAdjustment) key:CharonTitleOffset];
    [_owner charon_notify];
}

- (UIColor *)iconColor
{
    return [self charon_resolve:CharonIcon];
}

- (void)setIconColor:(UIColor *)iconColor
{
    [self charon_setValue:[iconColor copy] key:CharonIcon];
    [_owner charon_notify];
}

- (UIOffset)badgePositionAdjustment
{
    return charon_offset_unpack([self charon_resolve:CharonBadgeOffset]);
}

- (void)setBadgePositionAdjustment:(UIOffset)badgePositionAdjustment
{
    [self charon_setValue:charon_offset_pack(badgePositionAdjustment) key:CharonBadgeOffset];
    [_owner charon_notify];
}

- (UIColor *)badgeBackgroundColor
{
    return [self charon_resolve:CharonBadgeBackground];
}

- (void)setBadgeBackgroundColor:(UIColor *)badgeBackgroundColor
{
    [self charon_setValue:[badgeBackgroundColor copy] key:CharonBadgeBackground];
    [_owner charon_notify];
}

- (NSDictionary *)badgeTextAttributes
{
    return [self charon_resolve:CharonBadgeTitle];
}

- (void)setBadgeTextAttributes:(NSDictionary *)badgeTextAttributes
{
    [self charon_setAttributes:badgeTextAttributes key:CharonBadgeTitle];
    [_owner charon_notify];
}

- (UIOffset)badgeTitlePositionAdjustment
{
    return charon_offset_unpack([self charon_resolve:CharonBadgeTitleOffset]);
}

- (void)setBadgeTitlePositionAdjustment:(UIOffset)badgeTitlePositionAdjustment
{
    [self charon_setValue:charon_offset_pack(badgeTitlePositionAdjustment) key:CharonBadgeTitleOffset];
    [_owner charon_notify];
}

- (NSString *)charon_text
{
    NSMutableArray *parts = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"titleTextAttributes=%@", charon_attributes_text(_custom[CharonTitle])]];
    if (_custom[CharonTitleOffset])
        [parts addObject:[NSString stringWithFormat:@"titlePositionAdjustment=%@", charon_offset_text(_custom[CharonTitleOffset])]];
    [parts addObject:[NSString stringWithFormat:@"iconColor=%@", charon_text(_custom[CharonIcon])]];
    if (_custom[CharonBadgeOffset])
        [parts addObject:[NSString stringWithFormat:@"badgePositionAdjustment=%@", charon_offset_text(_custom[CharonBadgeOffset])]];
    [parts addObject:[NSString stringWithFormat:@"badgeBackgroundColor=%@", charon_text(_custom[CharonBadgeBackground])]];
    [parts addObject:[NSString stringWithFormat:@"badgeTextAttributes=%@", charon_attributes_text(_custom[CharonBadgeTitle])]];
    if (_custom[CharonBadgeTitleOffset])
        [parts addObject:[NSString stringWithFormat:@"badgeTitlePositionAdjustment=%@", charon_offset_text(_custom[CharonBadgeTitleOffset])]];
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

static void charon_check_item_style(NSInteger style)
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
    charon_check_item_style(style);
    if ((self = [super init]))
        [self charon_setUpStyle:style];
    return self;
}

- (void)charon_setUpStyle:(NSInteger)style
{
    _style = style;
    NSMutableArray *states = [NSMutableArray array];
    for (NSInteger state = 0; state < 4; state++)
        [states addObject:[[UITabBarItemStateAppearance alloc] initCharonWithOwner:self state:state]];
    _states = states;
}

- (instancetype)initCharonWithStyle:(NSInteger)style
{
    if ((self = [self initWithStyle:UITabBarItemAppearanceStyleStacked]))
        [self charon_setUpStyle:style];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSInteger style = [coder decodeIntegerForKey:@"style"];
    if ((self = [super init])) {
        [self charon_setUpStyle:(style >= 0 && style <= 4) ? style : 0];
        NSArray *names = @[@"normal", @"selected", @"disabled", @"focused"];
        for (NSInteger state = 0; state < 4; state++) {
            id packed = [coder decodeObjectOfClasses:charon_plist_classes() forKey:names[state]];
            [[_states[state] charon_custom] setDictionary:charon_sanitised(charon_plist_unpack(packed), charon_item_classes(), nil)];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_style forKey:@"style"];
    NSArray *names = @[@"normal", @"selected", @"disabled", @"focused"];
    for (NSInteger state = 0; state < 4; state++)
        [coder encodeObject:charon_plist_pack([_states[state] charon_custom]) forKey:names[state]];
}

- (id)copyWithZone:(NSZone *)zone
{
    UITabBarItemAppearance *copy = [[[self class] allocWithZone:zone] initCharonWithStyle:_style];
    for (NSInteger state = 0; state < 4; state++)
        [[copy->_states[state] charon_custom] setDictionary:[_states[state] charon_custom]];
    return copy;
}

- (instancetype)copy
{
    return [self copyWithZone:nil];
}

- (void)configureWithDefaultForStyle:(UITabBarItemAppearanceStyle)style
{
    charon_check_item_style(style);
    _style = style;
    for (UITabBarItemStateAppearance *state in _states)
        [[state charon_custom] removeAllObjects];
    [self charon_notify];
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

- (void)charon_setChangeObserver:(void (^)(void))observer
{
    _changeObserver = [observer copy];
}

- (void)charon_notify
{
    if (_changeObserver)
        _changeObserver();
}

- (NSInteger)charon_style
{
    return _style;
}

- (NSDictionary *)charon_customOfState:(NSInteger)state
{
    return [_states[state] charon_custom];
}

- (id)charon_resolveState:(NSInteger)state key:(NSString *)key
{
    NSMutableArray *customs = [NSMutableArray array];
    for (UITabBarItemStateAppearance *one in _states)
        [customs addObject:[one charon_custom]];
    return charon_item_resolve(_style, customs, state, key);
}

- (NSString *)charon_text
{
    NSArray *styles = @[@"stacked", @"inline", @"compactInline", @"carplay", @"tv"];
    NSMutableString *text = [NSMutableString stringWithFormat:@"baseStyle=%@", styles[_style]];
    NSArray *names = @[@"normal", @"selected", @"disabled", @"focused"];
    for (NSInteger state = 0; state < 4; state++)
        [text appendFormat:@" %@=%@", names[state], [_states[state] charon_text]];
    return text;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> %@", [self class], self, [self charon_text]];
}

- (NSArray *)charon_signature
{
    NSMutableArray *signature = [NSMutableArray arrayWithObject:@(_style)];
    for (UITabBarItemStateAppearance *state in _states) {
        NSMutableDictionary *custom = [NSMutableDictionary dictionaryWithDictionary:[state charon_custom]];
        for (NSString *key in @[CharonTitleOffset, CharonBadgeOffset, CharonBadgeTitleOffset])
            if ([custom[key] isEqual:charon_offset_pack(UIOffsetZero)])
                [custom removeObjectForKey:key];
        [signature addObject:custom];
    }
    return signature;
}

- (BOOL)isEqual:(id)object
{
    return object == self || ([object isKindOfClass:[UITabBarItemAppearance class]] && [[self charon_signature] isEqual:[object charon_signature]]);
}

- (NSUInteger)hash
{
    return [[self charon_signature] hash];
}

@end
