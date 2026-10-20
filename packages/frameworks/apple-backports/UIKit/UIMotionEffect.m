#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <string.h>

static NSString *const RevenantKeyPathKey = @"_keyPath";
static NSString *const RevenantTypeKey = @"_type";
static NSString *const RevenantMinimumKey = @"_minimumRelativeValue";
static NSString *const RevenantMaximumKey = @"_maximumRelativeValue";
static NSString *const RevenantEffectsKey = @"_motionEffects";

enum { revenant_max_components = 16 };

static NSUInteger revenant_components(id value, CGFloat *components)
{
    if ([value isKindOfClass:[NSNumber class]]) {
        components[0] = (CGFloat)[value doubleValue];
        return 1;
    }
    if (![value isKindOfClass:[NSValue class]])
        return 0;
    const char *type = [value objCType];
    static const char *const types[] = {@encode(CGPoint), @encode(CGSize), @encode(CGRect), @encode(CGAffineTransform), @encode(CATransform3D), @encode(UIOffset), @encode(UIEdgeInsets)};
    static const NSUInteger counts[] = {2, 2, 4, 6, 16, 2, 4};
    for (NSUInteger index = 0; index < sizeof(types) / sizeof(*types); index++) {
        if (strcmp(type, types[index]) == 0) {
            [value getValue:components];
            return counts[index];
        }
    }
    return 0;
}

static id revenant_value_like(id model, const CGFloat *components)
{
    if ([model isKindOfClass:[NSNumber class]])
        return [NSNumber numberWithDouble:components[0]];
    return [NSValue valueWithBytes:components objCType:[model objCType]];
}

static id revenant_combine(id first, id second, CGFloat firstWeight, CGFloat secondWeight)
{
    CGFloat left[revenant_max_components], right[revenant_max_components], result[revenant_max_components];
    NSUInteger count = revenant_components(first, left);
    if (!count || revenant_components(second, right) != count)
        return nil;
    if ([first isKindOfClass:[NSNumber class]] != [second isKindOfClass:[NSNumber class]])
        return nil;
    if (![first isKindOfClass:[NSNumber class]] && strcmp([first objCType], [second objCType]) != 0)
        return nil;
    for (NSUInteger index = 0; index < count; index++)
        result[index] = left[index] * firstWeight + right[index] * secondWeight;
    return revenant_value_like(first, result);
}

@implementation UIMotionEffect

+ (id)revenant_sumOfRelativeValue:(id)first andRelativeValue:(id)second
{
    return revenant_combine(first, second, 1, 1);
}

+ (id)revenant_relativeValue:(id)value scaledBy:(CGFloat)factor
{
    return revenant_combine(value, value, factor, 0);
}

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] init];
}

- (NSDictionary *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)viewerOffset
{
    return nil;
}

@end

@implementation UIInterpolatingMotionEffect {
    NSString *_keyPath;
    UIInterpolatingMotionEffectType _type;
    id _minimumRelativeValue;
    id _maximumRelativeValue;
}

- (instancetype)init
{
    NSString *keyPath = nil;
    return [self initWithKeyPath:keyPath type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
}

- (instancetype)initWithKeyPath:(NSString *)keyPath type:(UIInterpolatingMotionEffectType)type
{
    if ((self = [super init])) {
        _keyPath = [keyPath copy];
        _type = type;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _keyPath = [[coder decodeObjectForKey:RevenantKeyPathKey] copy];
        _type = (UIInterpolatingMotionEffectType)[coder decodeIntegerForKey:RevenantTypeKey];
        _minimumRelativeValue = [coder decodeObjectForKey:RevenantMinimumKey];
        _maximumRelativeValue = [coder decodeObjectForKey:RevenantMaximumKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_keyPath forKey:RevenantKeyPathKey];
    [coder encodeInteger:_type forKey:RevenantTypeKey];
    [coder encodeObject:_minimumRelativeValue forKey:RevenantMinimumKey];
    [coder encodeObject:_maximumRelativeValue forKey:RevenantMaximumKey];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIInterpolatingMotionEffect *copy = [[[self class] allocWithZone:zone] initWithKeyPath:_keyPath type:_type];
    copy->_minimumRelativeValue = _minimumRelativeValue;
    copy->_maximumRelativeValue = _maximumRelativeValue;
    return copy;
}

- (NSString *)keyPath
{
    return _keyPath;
}

- (UIInterpolatingMotionEffectType)type
{
    return _type;
}

- (id)minimumRelativeValue
{
    return _minimumRelativeValue;
}

- (void)setMinimumRelativeValue:(id)minimumRelativeValue
{
    _minimumRelativeValue = minimumRelativeValue;
}

- (id)maximumRelativeValue
{
    return _maximumRelativeValue;
}

- (void)setMaximumRelativeValue:(id)maximumRelativeValue
{
    _maximumRelativeValue = maximumRelativeValue;
}

- (NSDictionary *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)viewerOffset
{
    if (!_keyPath.length || !_minimumRelativeValue || !_maximumRelativeValue)
        return nil;
    CGFloat offset = _type == UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis ? viewerOffset.horizontal : -viewerOffset.vertical;
    offset = MAX(-1, MIN(1, offset));
    CGFloat progress = (offset + 1) / 2;
    id value = revenant_combine(_minimumRelativeValue, _maximumRelativeValue, 1 - progress, progress);
    return value ? [NSDictionary dictionaryWithObject:value forKey:_keyPath] : nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; keyPath = %@; type = %@; minimumRelativeValue = %@; maximumRelativeValue = %@>", [self class], self, _keyPath,
            _type == UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis ? @"horizontal" : @"vertical", _minimumRelativeValue, _maximumRelativeValue];
}

@end

@implementation UIMotionEffectGroup {
    NSArray *_motionEffects;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        _motionEffects = [[coder decodeObjectForKey:RevenantEffectsKey] copy];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_motionEffects forKey:RevenantEffectsKey];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIMotionEffectGroup *copy = [[[self class] allocWithZone:zone] init];
    copy->_motionEffects = _motionEffects;
    return copy;
}

- (NSArray *)motionEffects
{
    return _motionEffects;
}

- (void)setMotionEffects:(NSArray *)motionEffects
{
    _motionEffects = [motionEffects copy];
}

- (NSDictionary *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)viewerOffset
{
    NSMutableDictionary *merged = [NSMutableDictionary dictionary];
    for (UIMotionEffect *effect in _motionEffects) {
        NSDictionary *values = [effect keyPathsAndRelativeValuesForViewerOffset:viewerOffset];
        for (NSString *keyPath in values) {
            id value = [values objectForKey:keyPath];
            id existing = [merged objectForKey:keyPath];
            id combined = existing ? revenant_combine(existing, value, 1, 1) : value;
            if (combined)
                [merged setObject:combined forKey:keyPath];
        }
    }
    return merged.count ? merged : nil;
}

@end
