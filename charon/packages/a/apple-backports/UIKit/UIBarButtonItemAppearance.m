#import "CharonBarAppearance.h"

static NSString *const CharonTitle = @"title";
static NSString *const CharonTitleOffset = @"titleOffset";
static NSString *const CharonBackground = @"background";
static NSString *const CharonBackgroundOffset = @"backgroundOffset";
static NSString *const CharonBackIndicator = @"backIndicator";
static NSString *const CharonBackMask = @"backMask";

static NSDictionary *charon_button_classes(void)
{
    return @{CharonTitle: [NSDictionary class], CharonTitleOffset: [NSArray class], CharonBackground: [UIImage class], CharonBackgroundOffset: [NSArray class]};
}

static NSArray *charon_button_chain(NSInteger state)
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

static id charon_button_resolve(NSInteger style, UIBarButtonItemAppearance *basedOn, NSArray *customs, NSInteger state, NSString *key)
{
    NSArray *chain = charon_button_chain(state);
    if ([key isEqual:CharonTitle]) {
        NSDictionary *resolved = basedOn ? charon_attributes_carried([basedOn charon_resolveState:state key:key], YES, NO)
                                         : @{NSFontAttributeName: charon_font(17, style == 2 ? UIFontWeightSemibold : UIFontWeightMedium)};
        for (NSInteger index = (NSInteger)chain.count - 1; index >= 0; index--) {
            NSInteger from = [chain[index] integerValue];
            NSDictionary *own = customs[from][key];
            resolved = charon_attributes_merge(resolved, from == state ? own : charon_attributes_carried(own, YES, state == 2));
        }
        return resolved;
    }
    if ([key isEqual:CharonBackground])
        return customs[state][key] ?: [basedOn charon_customOfState:state][key];
    for (NSNumber *from in chain)
        if (customs[[from integerValue]][key])
            return customs[[from integerValue]][key];
    return [basedOn charon_customOfState:state][key] ?: charon_offset_pack(UIOffsetZero);
}

@implementation UIBarButtonItemStateAppearance {
@private
    __weak UIBarButtonItemAppearance *_owner;
    NSInteger _state;
    NSMutableDictionary *_custom;
}

- (instancetype)initCharonWithOwner:(UIBarButtonItemAppearance *)owner state:(NSInteger)state
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
    return charon_button_resolve(0, nil, customs, _state, key);
}

- (void)charon_setValue:(id)value key:(NSString *)key
{
    if (!value)
        [_custom removeObjectForKey:key];
    else if (!charon_same(value, [self charon_resolve:key]))
        _custom[key] = value;
}

- (NSDictionary *)titleTextAttributes
{
    return [self charon_resolve:CharonTitle];
}

- (void)setTitleTextAttributes:(NSDictionary *)titleTextAttributes
{
    if (!titleTextAttributes.count)
        [_custom removeObjectForKey:CharonTitle];
    else if (![titleTextAttributes isEqual:[self charon_resolve:CharonTitle]])
        _custom[CharonTitle] = [titleTextAttributes copy];
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

- (UIImage *)backgroundImage
{
    return [self charon_resolve:CharonBackground];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    [self charon_setValue:backgroundImage key:CharonBackground];
    [_owner charon_notify];
}

- (UIOffset)backgroundImagePositionAdjustment
{
    return charon_offset_unpack([self charon_resolve:CharonBackgroundOffset]);
}

- (void)setBackgroundImagePositionAdjustment:(UIOffset)backgroundImagePositionAdjustment
{
    [self charon_setValue:charon_offset_pack(backgroundImagePositionAdjustment) key:CharonBackgroundOffset];
    [_owner charon_notify];
}

- (NSString *)charon_text
{
    NSMutableArray *parts = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"titleTextAttributes=%@", charon_attributes_text(_custom[CharonTitle])]];
    if (_custom[CharonTitleOffset])
        [parts addObject:[NSString stringWithFormat:@"titlePositionAdjustment=%@", charon_offset_text(_custom[CharonTitleOffset])]];
    if (_custom[CharonBackground])
        [parts addObject:[NSString stringWithFormat:@"backgroundImage=%@", _custom[CharonBackground]]];
    if (_custom[CharonBackground] && _custom[CharonBackgroundOffset])
        [parts addObject:[NSString stringWithFormat:@"backgroundImagePositionAdjustment=%@", charon_offset_text(_custom[CharonBackgroundOffset])]];
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

static void charon_check_button_style(NSInteger style)
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
    charon_check_button_style(style);
    if ((self = [super init]))
        [self charon_setUpStyle:style == 7 ? 0 : style];
    return self;
}

- (void)charon_setUpStyle:(NSInteger)style
{
    _style = style;
    NSMutableArray *states = [NSMutableArray array];
    for (NSInteger state = 0; state < 4; state++)
        [states addObject:[[UIBarButtonItemStateAppearance alloc] initCharonWithOwner:self state:state]];
    _states = states;
}

- (instancetype)initCharonWithStyle:(NSInteger)style
{
    if ((self = [self initWithStyle:UIBarButtonItemStylePlain]))
        [self charon_setUpStyle:style];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSInteger style = [coder decodeIntegerForKey:@"style"];
    if ((self = [super init])) {
        [self charon_setUpStyle:(style == 2 || style == 3) ? style : 0];
        NSArray *names = @[@"normal", @"highlighted", @"disabled", @"focused"];
        for (NSInteger state = 0; state < 4; state++) {
            id packed = [coder decodeObjectOfClasses:charon_plist_classes() forKey:names[state]];
            [[_states[state] charon_custom] setDictionary:charon_sanitised(charon_plist_unpack(packed), charon_button_classes(), nil)];
        }
        NSDictionary *indicator = charon_sanitised(charon_plist_unpack([coder decodeObjectOfClasses:charon_plist_classes() forKey:@"indicator"]),
                                                   @{CharonBackIndicator: [UIImage class], CharonBackMask: [UIImage class]}, nil);
        _backIndicator = indicator[CharonBackIndicator];
        _backMask = indicator[CharonBackMask];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_style forKey:@"style"];
    NSArray *names = @[@"normal", @"highlighted", @"disabled", @"focused"];
    for (NSInteger state = 0; state < 4; state++)
        [coder encodeObject:charon_plist_pack([_states[state] charon_custom]) forKey:names[state]];
    NSMutableDictionary *indicator = [NSMutableDictionary dictionary];
    if (_backIndicator)
        indicator[CharonBackIndicator] = _backIndicator;
    if (_backMask)
        indicator[CharonBackMask] = _backMask;
    [coder encodeObject:charon_plist_pack(indicator) forKey:@"indicator"];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIBarButtonItemAppearance *copy = [[[self class] allocWithZone:zone] initCharonWithStyle:_style];
    for (NSInteger state = 0; state < 4; state++)
        [[copy->_states[state] charon_custom] setDictionary:[_states[state] charon_custom]];
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
    charon_check_button_style(style);
    _style = style == 7 ? 0 : style;
    _basedOn = nil;
    _backIndicator = nil;
    _backMask = nil;
    for (UIBarButtonItemStateAppearance *state in _states)
        [[state charon_custom] removeAllObjects];
    [self charon_notify];
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

- (UIBarButtonItemAppearance *)charon_basedOn
{
    return _basedOn;
}

- (NSDictionary *)charon_customOfState:(NSInteger)state
{
    return [_states[state] charon_custom];
}

- (id)charon_resolveState:(NSInteger)state key:(NSString *)key
{
    NSMutableArray *customs = [NSMutableArray array];
    for (UIBarButtonItemStateAppearance *one in _states)
        [customs addObject:[one charon_custom]];
    return charon_button_resolve(_style, _basedOn, customs, state, key);
}

- (void)charon_becomeBackButtonBasedOn:(UIBarButtonItemAppearance *)button
{
    _style = 3;
    _basedOn = button;
}

- (void)charon_setBackIndicator:(UIImage *)image mask:(UIImage *)mask
{
    _backIndicator = image;
    _backMask = mask;
    [self charon_notify];
}

- (UIImage *)charon_backIndicator
{
    return _backIndicator;
}

- (UIImage *)charon_backMask
{
    return _backMask;
}

- (NSString *)charon_text
{
    NSString *styles[] = {@"plain", @"plain", @"prominent", @"backButton"};
    NSMutableString *text = [NSMutableString stringWithFormat:@"baseStyle=%@", styles[_style]];
    if (_style == 3) {
        BOOL both = _backIndicator && _backMask;
        [text appendFormat:@" backIndicator=%@ mask=%@", both ? _backIndicator : @"default", both ? _backMask : @"default"];
    }
    NSArray *names = @[@"normal", @"highlighted", @"disabled", @"focused"];
    for (NSInteger state = 0; state < 4; state++)
        [text appendFormat:@" %@=%@", names[state], [_states[state] charon_text]];
    if (_style == 3)
        [text appendFormat:@" basedOn=%p", _basedOn];
    return text;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> %@", [self class], self, [self charon_text]];
}

- (NSArray *)charon_signature
{
    NSMutableArray *signature = [NSMutableArray arrayWithObject:@(_style)];
    for (UIBarButtonItemStateAppearance *state in _states) {
        NSMutableDictionary *custom = [NSMutableDictionary dictionaryWithDictionary:[state charon_custom]];
        if ([custom[CharonTitleOffset] isEqual:charon_offset_pack(UIOffsetZero)])
            [custom removeObjectForKey:CharonTitleOffset];
        [signature addObject:custom];
    }
    [signature addObject:_backIndicator && _backMask ? _backIndicator : [NSNull null]];
    [signature addObject:_backIndicator && _backMask ? _backMask : [NSNull null]];
    return signature;
}

- (BOOL)isEqual:(id)object
{
    return object == self || ([object isKindOfClass:[UIBarButtonItemAppearance class]] && [[self charon_signature] isEqual:[object charon_signature]]);
}

- (NSUInteger)hash
{
    return [[self charon_signature] hash];
}

@end
