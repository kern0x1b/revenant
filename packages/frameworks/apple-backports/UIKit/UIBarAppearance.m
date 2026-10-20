#import "RevenantBarAppearance.h"

static NSString *const RevenantEffect = @"effect";
static NSString *const RevenantColour = @"color";
static NSString *const RevenantImage = @"image";
static NSString *const RevenantImageMode = @"imageMode";
static NSString *const RevenantShadowColour = @"shadowColor";
static NSString *const RevenantShadowImage = @"shadowImage";
static NSString *const RevenantVisibility = @"visibility";

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
        [self revenant_setUp];
    }
    return self;
}

- (instancetype)initWithBarAppearance:(UIBarAppearance *)barAppearance
{
    if ((self = [super init])) {
        _idiom = barAppearance.idiom;
        _values = [[NSMutableDictionary alloc] init];
        [self revenant_setUp];
        [_values setDictionary:barAppearance->_values];
        [self revenant_copyExtrasFrom:barAppearance];
    }
    return self;
}

- (void)revenant_setUp
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSInteger idiom = [coder decodeIntegerForKey:@"idiom"];
        _idiom = idiom == UIUserInterfaceIdiomPad ? UIUserInterfaceIdiomPad : UIUserInterfaceIdiomPhone;
        _values = [[NSMutableDictionary alloc] init];
        [self revenant_setUp];
        NSDictionary *classes = @{RevenantEffect: [UIBlurEffect class], RevenantColour: [UIColor class], RevenantImage: [UIImage class], RevenantImageMode: [NSNumber class],
                                  RevenantShadowColour: [UIColor class], RevenantShadowImage: [UIImage class], RevenantVisibility: [NSNumber class]};
        id packed = [coder decodeObjectOfClasses:revenant_plist_classes() forKey:@"values"];
        [_values setDictionary:revenant_sanitised(revenant_plist_unpack(packed), classes, [NSSet setWithObjects:RevenantEffect, RevenantShadowColour, nil])];
        [self revenant_decodeExtrasWithCoder:coder];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_idiom forKey:@"idiom"];
    [coder encodeObject:revenant_plist_pack(_values) forKey:@"values"];
    [self revenant_encodeExtrasWithCoder:coder];
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

- (NSMutableDictionary *)revenant_values
{
    return _values;
}

- (void)revenant_copyExtrasFrom:(UIBarAppearance *)source
{
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

- (void)revenant_encodeExtrasWithCoder:(NSCoder *)coder
{
}

- (void)revenant_decodeExtrasWithCoder:(NSCoder *)coder
{
}

- (void)configureWithDefaultBackground
{
    [_values removeAllObjects];
    [self revenant_notify];
}

- (void)configureWithOpaqueBackground
{
    [_values removeAllObjects];
    _values[RevenantEffect] = [NSNull null];
    _values[RevenantColour] = revenant_white_colour();
    _values[RevenantVisibility] = @1;
    [self revenant_notify];
}

- (void)revenant_configureTransparent
{
    [_values removeAllObjects];
    _values[RevenantEffect] = [NSNull null];
    _values[RevenantShadowColour] = [NSNull null];
    _values[RevenantVisibility] = @2;
    [self revenant_notify];
}

- (void)configureWithTransparentBackground
{
    [self revenant_configureTransparent];
}

- (UIBlurEffect *)backgroundEffect
{
    id effect = _values[RevenantEffect];
    if (!effect)
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    return effect == [NSNull null] ? nil : effect;
}

- (void)setBackgroundEffect:(UIBlurEffect *)backgroundEffect
{
    _values[RevenantEffect] = [backgroundEffect copy] ?: [NSNull null];
    [self revenant_notify];
}

- (UIColor *)backgroundColor
{
    return _values[RevenantColour];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    if (backgroundColor)
        _values[RevenantColour] = [backgroundColor copy];
    else
        [_values removeObjectForKey:RevenantColour];
    [self revenant_notify];
}

- (UIImage *)backgroundImage
{
    return _values[RevenantImage];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    if (backgroundImage)
        _values[RevenantImage] = backgroundImage;
    else
        [_values removeObjectForKey:RevenantImage];
    [self revenant_notify];
}

- (UIViewContentMode)backgroundImageContentMode
{
    return (UIViewContentMode)[_values[RevenantImageMode] integerValue];
}

- (void)setBackgroundImageContentMode:(UIViewContentMode)backgroundImageContentMode
{
    _values[RevenantImageMode] = @(backgroundImageContentMode);
    [self revenant_notify];
}

- (UIColor *)shadowColor
{
    id colour = _values[RevenantShadowColour];
    if (!colour)
        return revenant_default_shadow_colour();
    return colour == [NSNull null] ? nil : colour;
}

- (void)setShadowColor:(UIColor *)shadowColor
{
    _values[RevenantShadowColour] = [shadowColor copy] ?: [NSNull null];
    [self revenant_notify];
}

- (UIImage *)shadowImage
{
    return _values[RevenantShadowImage];
}

- (void)setShadowImage:(UIImage *)shadowImage
{
    if (shadowImage)
        _values[RevenantShadowImage] = shadowImage;
    else
        [_values removeObjectForKey:RevenantShadowImage];
    [self revenant_notify];
}

- (NSArray *)revenant_lines
{
    NSMutableString *line = [NSMutableString stringWithFormat:@"Background(%p):", _values];
    if (self.backgroundEffect)
        [line appendFormat:@" effect=(%@)", self.backgroundEffect];
    if (_values[RevenantColour])
        [line appendFormat:@" color=%@", _values[RevenantColour]];
    if (_values[RevenantImage])
        [line appendFormat:@" image=%@ contentMode=%ld", _values[RevenantImage], (long)self.backgroundImageContentMode];
    if (_values[RevenantVisibility])
        [line appendFormat:@" visibility=%@", [_values[RevenantVisibility] integerValue] == 1 ? @"visible" : @"hidden"];
    if (self.shadowColor)
        [line appendFormat:@" shadowColor=%@", self.shadowColor];
    if (_values[RevenantShadowImage])
        [line appendFormat:@" shadowImage=%@", _values[RevenantShadowImage]];
    return @[line];
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p>", [self class], self];
    for (NSString *line in [self revenant_lines])
        [text appendFormat:@"\n\t%@", line];
    return text;
}

- (NSArray *)revenant_signature
{
    return @[self.backgroundEffect ?: [NSNull null], _values[RevenantColour] ?: [NSNull null], _values[RevenantImage] ?: [NSNull null], @(self.backgroundImageContentMode),
             self.shadowColor ?: [NSNull null], _values[RevenantShadowImage] ?: [NSNull null], _values[RevenantVisibility] ?: @0];
}

- (BOOL)isEqual:(id)object
{
    return object == self || ([object isMemberOfClass:[self class]] && [[self revenant_signature] isEqual:[object revenant_signature]]);
}

- (NSUInteger)hash
{
    return [[self revenant_signature] hash];
}

@end
