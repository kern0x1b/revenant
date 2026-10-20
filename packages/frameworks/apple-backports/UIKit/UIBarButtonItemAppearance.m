#import "RevenantBarAppearance.h"

static NSString *const RevenantTitle = @"title";
static NSString *const RevenantTitleOffset = @"titleOffset";
static NSString *const RevenantBackground = @"background";
static NSString *const RevenantBackgroundOffset = @"backgroundOffset";
static NSString *const RevenantBackIndicator = @"backIndicator";
static NSString *const RevenantBackMask = @"backMask";

static NSDictionary *revenant_button_classes(void)
{
    return @{RevenantTitle: [NSDictionary class], RevenantTitleOffset: [NSArray class], RevenantBackground: [UIImage class], RevenantBackgroundOffset: [NSArray class]};
}

static NSArray *revenant_button_chain(NSInteger state)
{
    switch (state) {
    case 1:
        return @[@1, @0];
    case 2:
        return @[@2, @0];
    case 3:
        return @[@3, @1, @0];
    }
    return @[@0];
}

static id revenant_button_resolve(NSInteger style, UIBarButtonItemAppearance *basedOn, NSArray *customs, NSInteger state, NSString *key)
{
    NSArray *chain = revenant_button_chain(state);
    if ([key isEqual:RevenantTitle]) {
        NSDictionary *resolved = basedOn ? revenant_attributes_carried([basedOn revenant_resolveState:state key:key], YES, NO)
                                         : @{NSFontAttributeName: revenant_font(17, style == 2 ? UIFontWeightSemibold : UIFontWeightMedium)};
        for (NSInteger index = (NSInteger)chain.count - 1; index >= 0; index--) {
            NSInteger from = [chain[index] integerValue];
            NSDictionary *own = customs[from][key];
            resolved = revenant_attributes_merge(resolved, from == state ? own : revenant_attributes_carried(own, YES, state == 2));
        }
        return resolved;
    }
    if ([key isEqual:RevenantBackground])
        return customs[state][key] ?: [basedOn revenant_customOfState:state][key];
    for (NSNumber *from in chain)
        if (customs[[from integerValue]][key])
            return customs[[from integerValue]][key];
    return [basedOn revenant_customOfState:state][key] ?: revenant_offset_pack(UIOffsetZero);
}

@implementation UIBarButtonItemStateAppearance {
@private
    __weak UIBarButtonItemAppearance *_owner;
    NSInteger _state;
    NSMutableDictionary *_custom;
}

- (instancetype)initRevenantWithOwner:(UIBarButtonItemAppearance *)owner state:(NSInteger)state
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
    return revenant_button_resolve(0, nil, customs, _state, key);
}

- (void)revenant_setValue:(id)value key:(NSString *)key
{
    if (!value)
        [_custom removeObjectForKey:key];
    else if (!revenant_same(value, [self revenant_resolve:key]))
        _custom[key] = value;
}

- (NSDictionary *)titleTextAttributes
{
    return [self revenant_resolve:RevenantTitle];
}

- (void)setTitleTextAttributes:(NSDictionary *)titleTextAttributes
{
    if (!titleTextAttributes.count)
        [_custom removeObjectForKey:RevenantTitle];
    else if (![titleTextAttributes isEqual:[self revenant_resolve:RevenantTitle]])
        _custom[RevenantTitle] = [titleTextAttributes copy];
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

- (UIImage *)backgroundImage
{
    return [self revenant_resolve:RevenantBackground];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    [self revenant_setValue:backgroundImage key:RevenantBackground];
    [_owner revenant_notify];
}

- (UIOffset)backgroundImagePositionAdjustment
{
    return revenant_offset_unpack([self revenant_resolve:RevenantBackgroundOffset]);
}

- (void)setBackgroundImagePositionAdjustment:(UIOffset)backgroundImagePositionAdjustment
{
    [self revenant_setValue:revenant_offset_pack(backgroundImagePositionAdjustment) key:RevenantBackgroundOffset];
    [_owner revenant_notify];
}

- (NSString *)revenant_text
{
    NSMutableArray *parts = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"titleTextAttributes=%@", revenant_attributes_text(_custom[RevenantTitle])]];
    if (_custom[RevenantTitleOffset])
        [parts addObject:[NSString stringWithFormat:@"titlePositionAdjustment=%@", revenant_offset_text(_custom[RevenantTitleOffset])]];
    if (_custom[RevenantBackground])
        [parts addObject:[NSString stringWithFormat:@"backgroundImage=%@", _custom[RevenantBackground]]];
    if (_custom[RevenantBackground] && _custom[RevenantBackgroundOffset])
        [parts addObject:[NSString stringWithFormat:@"backgroundImagePositionAdjustment=%@", revenant_offset_text(_custom[RevenantBackgroundOffset])]];
    return [NSString stringWithFormat:@"(%@)", [parts componentsJoinedByString:@", "]];
}

@end

@implementation UIBarButtonItemAppearance {
@private
    NSInteger _style;
    NSArray *_states;
    __weak UIBarButtonItemAppearance *_basedOn;
    UIImage *_backIndicator;
    UIImage *_backMask;
    void (^_changeObserver)(void);
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

static void revenant_check_button_style(NSInteger style)
{
    if (style != 0 && style != 2 && style != 7)
        [NSException raise:NSInternalInconsistencyException format:@"Unsupported style: %ld", (long)style];
}

- (instancetype)init
{
    return [self initWithStyle:UIBarButtonItemStylePlain];
}

- (instancetype)initWithStyle:(UIBarButtonItemStyle)style
{
    revenant_check_button_style(style);
    if ((self = [super init]))
        [self revenant_setUpStyle:style == 7 ? 0 : style];
    return self;
}

- (void)revenant_setUpStyle:(NSInteger)style
{
    _style = style;
    NSMutableArray *states = [NSMutableArray array];
    for (NSInteger state = 0; state < 4; state++)
        [states addObject:[[UIBarButtonItemStateAppearance alloc] initRevenantWithOwner:self state:state]];
    _states = states;
}

- (instancetype)initRevenantWithStyle:(NSInteger)style
{
    if ((self = [self initWithStyle:UIBarButtonItemStylePlain]))
        [self revenant_setUpStyle:style];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSInteger style = [coder decodeIntegerForKey:@"style"];
    if ((self = [super init])) {
        [self revenant_setUpStyle:(style == 2 || style == 3) ? style : 0];
        NSArray *names = @[@"normal", @"highlighted", @"disabled", @"focused"];
        for (NSInteger state = 0; state < 4; state++) {
            id packed = [coder decodeObjectOfClasses:revenant_plist_classes() forKey:names[state]];
            [[_states[state] revenant_custom] setDictionary:revenant_sanitised(revenant_plist_unpack(packed), revenant_button_classes(), nil)];
        }
        NSDictionary *indicator = revenant_sanitised(revenant_plist_unpack([coder decodeObjectOfClasses:revenant_plist_classes() forKey:@"indicator"]),
                                                   @{RevenantBackIndicator: [UIImage class], RevenantBackMask: [UIImage class]}, nil);
        _backIndicator = indicator[RevenantBackIndicator];
        _backMask = indicator[RevenantBackMask];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_style forKey:@"style"];
    NSArray *names = @[@"normal", @"highlighted", @"disabled", @"focused"];
    for (NSInteger state = 0; state < 4; state++)
        [coder encodeObject:revenant_plist_pack([_states[state] revenant_custom]) forKey:names[state]];
    NSMutableDictionary *indicator = [NSMutableDictionary dictionary];
    if (_backIndicator)
        indicator[RevenantBackIndicator] = _backIndicator;
    if (_backMask)
        indicator[RevenantBackMask] = _backMask;
    [coder encodeObject:revenant_plist_pack(indicator) forKey:@"indicator"];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIBarButtonItemAppearance *copy = [[[self class] allocWithZone:zone] initRevenantWithStyle:_style];
    for (NSInteger state = 0; state < 4; state++)
        [[copy->_states[state] revenant_custom] setDictionary:[_states[state] revenant_custom]];
    copy->_basedOn = _basedOn;
    copy->_backIndicator = _backIndicator;
    copy->_backMask = _backMask;
    return copy;
}

- (instancetype)copy
{
    return [self copyWithZone:nil];
}

- (void)configureWithDefaultForStyle:(UIBarButtonItemStyle)style
{
    revenant_check_button_style(style);
    _style = style == 7 ? 0 : style;
    _basedOn = nil;
    _backIndicator = nil;
    _backMask = nil;
    for (UIBarButtonItemStateAppearance *state in _states)
        [[state revenant_custom] removeAllObjects];
    [self revenant_notify];
}

- (UIBarButtonItemStateAppearance *)normal
{
    return _states[0];
}

- (UIBarButtonItemStateAppearance *)highlighted
{
    return _states[1];
}

- (UIBarButtonItemStateAppearance *)disabled
{
    return _states[2];
}

- (UIBarButtonItemStateAppearance *)focused
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

- (UIBarButtonItemAppearance *)revenant_basedOn
{
    return _basedOn;
}

- (NSDictionary *)revenant_customOfState:(NSInteger)state
{
    return [_states[state] revenant_custom];
}

- (id)revenant_resolveState:(NSInteger)state key:(NSString *)key
{
    NSMutableArray *customs = [NSMutableArray array];
    for (UIBarButtonItemStateAppearance *one in _states)
        [customs addObject:[one revenant_custom]];
    return revenant_button_resolve(_style, _basedOn, customs, state, key);
}

- (void)revenant_becomeBackButtonBasedOn:(UIBarButtonItemAppearance *)button
{
    _style = 3;
    _basedOn = button;
}

- (void)revenant_setBackIndicator:(UIImage *)image mask:(UIImage *)mask
{
    _backIndicator = image;
    _backMask = mask;
    [self revenant_notify];
}

- (UIImage *)revenant_backIndicator
{
    return _backIndicator;
}

- (UIImage *)revenant_backMask
{
    return _backMask;
}

- (NSString *)revenant_text
{
    NSString *styles[] = {@"plain", @"plain", @"prominent", @"backButton"};
    NSMutableString *text = [NSMutableString stringWithFormat:@"baseStyle=%@", styles[_style]];
    if (_style == 3) {
        BOOL both = _backIndicator && _backMask;
        [text appendFormat:@" backIndicator=%@ mask=%@", both ? _backIndicator : @"default", both ? _backMask : @"default"];
    }
    NSArray *names = @[@"normal", @"highlighted", @"disabled", @"focused"];
    for (NSInteger state = 0; state < 4; state++)
        [text appendFormat:@" %@=%@", names[state], [_states[state] revenant_text]];
    if (_style == 3)
        [text appendFormat:@" basedOn=%p", _basedOn];
    return text;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> %@", [self class], self, [self revenant_text]];
}

- (NSArray *)revenant_signature
{
    NSMutableArray *signature = [NSMutableArray arrayWithObject:@(_style)];
    for (UIBarButtonItemStateAppearance *state in _states) {
        NSMutableDictionary *custom = [NSMutableDictionary dictionaryWithDictionary:[state revenant_custom]];
        if ([custom[RevenantTitleOffset] isEqual:revenant_offset_pack(UIOffsetZero)])
            [custom removeObjectForKey:RevenantTitleOffset];
        [signature addObject:custom];
    }
    [signature addObject:_backIndicator && _backMask ? _backIndicator : [NSNull null]];
    [signature addObject:_backIndicator && _backMask ? _backMask : [NSNull null]];
    return signature;
}

- (BOOL)isEqual:(id)object
{
    return object == self || ([object isKindOfClass:[UIBarButtonItemAppearance class]] && [[self revenant_signature] isEqual:[object revenant_signature]]);
}

- (NSUInteger)hash
{
    return [[self revenant_signature] hash];
}

@end
