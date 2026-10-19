#import "CharonBarAppearance.h"

static NSString *const CharonEffect = @"effect";
static NSString *const CharonColour = @"color";
static NSString *const CharonImage = @"image";
static NSString *const CharonImageMode = @"imageMode";
static NSString *const CharonShadowColour = @"shadowColor";
static NSString *const CharonShadowImage = @"shadowImage";
static NSString *const CharonVisibility = @"visibility";

@implementation UIBarAppearance {
@private
    UIUserInterfaceIdiom _idiom;
    NSMutableDictionary *_values;
    void (^_changeObserver)(void);
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    return [self initWithIdiom:[UIDevice currentDevice].userInterfaceIdiom];
}

- (instancetype)initWithIdiom:(UIUserInterfaceIdiom)idiom
{
    if ((self = [super init])) {
        _idiom = idiom == UIUserInterfaceIdiomPad ? UIUserInterfaceIdiomPad : UIUserInterfaceIdiomPhone;
        _values = [[NSMutableDictionary alloc] init];
        [self charon_setUp];
    }
    return self;
}

- (instancetype)initWithBarAppearance:(UIBarAppearance *)barAppearance
{
    if ((self = [super init])) {
        _idiom = barAppearance.idiom;
        _values = [[NSMutableDictionary alloc] init];
        [self charon_setUp];
        [_values setDictionary:barAppearance->_values];
        [self charon_copyExtrasFrom:barAppearance];
    }
    return self;
}

- (void)charon_setUp
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSInteger idiom = [coder decodeIntegerForKey:@"idiom"];
        _idiom = idiom == UIUserInterfaceIdiomPad ? UIUserInterfaceIdiomPad : UIUserInterfaceIdiomPhone;
        _values = [[NSMutableDictionary alloc] init];
        [self charon_setUp];
        NSDictionary *classes = @{CharonEffect: [UIBlurEffect class], CharonColour: [UIColor class], CharonImage: [UIImage class], CharonImageMode: [NSNumber class],
                                  CharonShadowColour: [UIColor class], CharonShadowImage: [UIImage class], CharonVisibility: [NSNumber class]};
        id packed = [coder decodeObjectOfClasses:charon_plist_classes() forKey:@"values"];
        [_values setDictionary:charon_sanitised(charon_plist_unpack(packed), classes, [NSSet setWithObjects:CharonEffect, CharonShadowColour, nil])];
        [self charon_decodeExtrasWithCoder:coder];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_idiom forKey:@"idiom"];
    [coder encodeObject:charon_plist_pack(_values) forKey:@"values"];
    [self charon_encodeExtrasWithCoder:coder];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithBarAppearance:self];
}

- (instancetype)copy
{
    return [self copyWithZone:nil];
}

- (UIUserInterfaceIdiom)idiom
{
    return _idiom;
}

- (NSMutableDictionary *)charon_values
{
    return _values;
}

- (void)charon_copyExtrasFrom:(UIBarAppearance *)source
{
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

- (void)charon_encodeExtrasWithCoder:(NSCoder *)coder
{
}

- (void)charon_decodeExtrasWithCoder:(NSCoder *)coder
{
}

- (void)configureWithDefaultBackground
{
    [_values removeAllObjects];
    [self charon_notify];
}

- (void)configureWithOpaqueBackground
{
    [_values removeAllObjects];
    _values[CharonEffect] = [NSNull null];
    _values[CharonColour] = charon_white_colour();
    _values[CharonVisibility] = @1;
    [self charon_notify];
}

- (void)charon_configureTransparent
{
    [_values removeAllObjects];
    _values[CharonEffect] = [NSNull null];
    _values[CharonShadowColour] = [NSNull null];
    _values[CharonVisibility] = @2;
    [self charon_notify];
}

- (void)configureWithTransparentBackground
{
    [self charon_configureTransparent];
}

- (UIBlurEffect *)backgroundEffect
{
    id effect = _values[CharonEffect];
    if (!effect)
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    return effect == [NSNull null] ? nil : effect;
}

- (void)setBackgroundEffect:(UIBlurEffect *)backgroundEffect
{
    _values[CharonEffect] = [backgroundEffect copy] ?: [NSNull null];
    [self charon_notify];
}

- (UIColor *)backgroundColor
{
    return _values[CharonColour];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    if (backgroundColor)
        _values[CharonColour] = [backgroundColor copy];
    else
        [_values removeObjectForKey:CharonColour];
    [self charon_notify];
}

- (UIImage *)backgroundImage
{
    return _values[CharonImage];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    if (backgroundImage)
        _values[CharonImage] = backgroundImage;
    else
        [_values removeObjectForKey:CharonImage];
    [self charon_notify];
}

- (UIViewContentMode)backgroundImageContentMode
{
    return (UIViewContentMode)[_values[CharonImageMode] integerValue];
}

- (void)setBackgroundImageContentMode:(UIViewContentMode)backgroundImageContentMode
{
    _values[CharonImageMode] = @(backgroundImageContentMode);
    [self charon_notify];
}

- (UIColor *)shadowColor
{
    id colour = _values[CharonShadowColour];
    if (!colour)
        return charon_default_shadow_colour();
    return colour == [NSNull null] ? nil : colour;
}

- (void)setShadowColor:(UIColor *)shadowColor
{
    _values[CharonShadowColour] = [shadowColor copy] ?: [NSNull null];
    [self charon_notify];
}

- (UIImage *)shadowImage
{
    return _values[CharonShadowImage];
}

- (void)setShadowImage:(UIImage *)shadowImage
{
    if (shadowImage)
        _values[CharonShadowImage] = shadowImage;
    else
        [_values removeObjectForKey:CharonShadowImage];
    [self charon_notify];
}

- (NSArray *)charon_lines
{
    NSMutableString *line = [NSMutableString stringWithFormat:@"Background(%p):", _values];
    if (self.backgroundEffect)
        [line appendFormat:@" effect=(%@)", self.backgroundEffect];
    if (_values[CharonColour])
        [line appendFormat:@" color=%@", _values[CharonColour]];
    if (_values[CharonImage])
        [line appendFormat:@" image=%@ contentMode=%ld", _values[CharonImage], (long)self.backgroundImageContentMode];
    if (_values[CharonVisibility])
        [line appendFormat:@" visibility=%@", [_values[CharonVisibility] integerValue] == 1 ? @"visible" : @"hidden"];
    if (self.shadowColor)
        [line appendFormat:@" shadowColor=%@", self.shadowColor];
    if (_values[CharonShadowImage])
        [line appendFormat:@" shadowImage=%@", _values[CharonShadowImage]];
    return @[line];
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p>", [self class], self];
    for (NSString *line in [self charon_lines])
        [text appendFormat:@"\n\t%@", line];
    return text;
}

- (NSArray *)charon_signature
{
    return @[self.backgroundEffect ?: [NSNull null], _values[CharonColour] ?: [NSNull null], _values[CharonImage] ?: [NSNull null], @(self.backgroundImageContentMode),
             self.shadowColor ?: [NSNull null], _values[CharonShadowImage] ?: [NSNull null], _values[CharonVisibility] ?: @0];
}

- (BOOL)isEqual:(id)object
{
    return object == self || ([object isMemberOfClass:[self class]] && [[self charon_signature] isEqual:[object charon_signature]]);
}

- (NSUInteger)hash
{
    return [[self charon_signature] hash];
}

@end
