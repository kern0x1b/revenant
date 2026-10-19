#import "CharonBlur.h"

@implementation UIVisualEffect

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

@end


@implementation UIBlurEffect {
    UIBlurEffectStyle _style;
}

+ (UIBlurEffect *)effectWithStyle:(UIBlurEffectStyle)style
{
    UIBlurEffect *effect = [[self alloc] init];
    effect->_style = style;
    return effect;
}

- (UIBlurEffectStyle)charon_style
{
    return _style;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_style forKey:@"UIBlurEffectStyle"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
        _style = [coder decodeIntegerForKey:@"UIBlurEffectStyle"];
    return self;
}

- (BOOL)isEqual:(id)other
{
    return other == self || ([other isKindOfClass:[UIBlurEffect class]] && ((UIBlurEffect *)other)->_style == _style);
}

- (NSUInteger)hash
{
    return (NSUInteger)_style;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> style=%ld", NSStringFromClass([self class]), self, (long)_style];
}

@end

@implementation UIVibrancyEffect {
    UIBlurEffectStyle _style;
}

+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect
{
    UIVibrancyEffect *effect = [[self alloc] init];
    effect->_style = blurEffect ? [blurEffect charon_style] : 0;
    return effect;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_style forKey:@"UIVibrancyEffectBlurStyle"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
        _style = [coder decodeIntegerForKey:@"UIVibrancyEffectBlurStyle"];
    return self;
}

- (BOOL)isEqual:(id)other
{
    return other == self || ([other isKindOfClass:[UIVibrancyEffect class]] && ((UIVibrancyEffect *)other)->_style == _style);
}

- (NSUInteger)hash
{
    return (NSUInteger)_style + 1000;
}

@end
