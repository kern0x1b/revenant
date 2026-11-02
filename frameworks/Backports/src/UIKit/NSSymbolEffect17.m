#import "RevenantSymbolEffects.h"

#import <math.h>
#import <objc/message.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"

static CFTimeInterval revenant_cycle_duration(NSSymbolEffectOptions *options)
{
    double speed = options.revenant_speed > 0 ? options.revenant_speed : 1;
    return 0.6 / speed;
}

static CAKeyframeAnimation *revenant_keyframes(NSString *keyPath, NSArray *values, NSSymbolEffectOptions *options)
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:keyPath];
    animation.values = values;
    animation.keyTimes = @[@0, @0.5, @1];
    animation.duration = revenant_cycle_duration(options);
    animation.repeatCount = options.revenant_repeating ? (options.revenant_repeatCount > 0 ? options.revenant_repeatCount : HUGE_VALF) : 1;
    animation.removedOnCompletion = YES;
    return animation;
}

@implementation NSSymbolEffect {
    BOOL _wholeSymbol;
    RevenantSymbolEffectDirection _direction;
}

- (BOOL)revenant_wholeSymbol
{
    return _wholeSymbol;
}

- (RevenantSymbolEffectDirection)revenant_direction
{
    return _direction;
}

- (instancetype)initRevenantWithWholeSymbol:(BOOL)wholeSymbol direction:(RevenantSymbolEffectDirection)direction
{
    if ((self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init")))) {
        _wholeSymbol = wholeSymbol;
        _direction = direction;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (CAAnimation *)revenant_animationForView:(UIView *)view options:(NSSymbolEffectOptions *)options
{
    return nil;
}

@end

@implementation NSSymbolBounceEffect

+ (instancetype)effect
{
    return [[self alloc] initRevenantWithWholeSymbol:NO direction:RevenantSymbolEffectDirectionDefault];
}

+ (instancetype)bounceUpEffect
{
    return [[self alloc] initRevenantWithWholeSymbol:NO direction:RevenantSymbolEffectDirectionUp];
}

+ (instancetype)bounceDownEffect
{
    return [[self alloc] initRevenantWithWholeSymbol:NO direction:RevenantSymbolEffectDirectionDown];
}

- (instancetype)effectWithByLayer
{
    return [[[self class] alloc] initRevenantWithWholeSymbol:NO direction:self.revenant_direction];
}

- (instancetype)effectWithWholeSymbol
{
    return [[[self class] alloc] initRevenantWithWholeSymbol:YES direction:self.revenant_direction];
}

- (CAAnimation *)revenant_animationForView:(UIView *)view options:(NSSymbolEffectOptions *)options
{
    CGFloat amplitude = view.bounds.size.height * 0.15;
    CGFloat offset = self.revenant_direction == RevenantSymbolEffectDirectionDown ? amplitude : -amplitude;
    return revenant_keyframes(@"transform.translation.y", @[@0, @(offset), @0], options);
}

@end

@implementation NSSymbolPulseEffect

+ (instancetype)effect
{
    return [[self alloc] initRevenantWithWholeSymbol:NO direction:RevenantSymbolEffectDirectionDefault];
}

- (instancetype)effectWithByLayer
{
    return [[[self class] alloc] initRevenantWithWholeSymbol:NO direction:self.revenant_direction];
}

- (instancetype)effectWithWholeSymbol
{
    return [[[self class] alloc] initRevenantWithWholeSymbol:YES direction:self.revenant_direction];
}

- (CAAnimation *)revenant_animationForView:(UIView *)view options:(NSSymbolEffectOptions *)options
{
    return revenant_keyframes(@"opacity", @[@1, @0.5, @1], options);
}

@end

@implementation NSSymbolScaleEffect

+ (instancetype)effect
{
    return [[self alloc] initRevenantWithWholeSymbol:NO direction:RevenantSymbolEffectDirectionDefault];
}

+ (instancetype)scaleUpEffect
{
    return [[self alloc] initRevenantWithWholeSymbol:NO direction:RevenantSymbolEffectDirectionUp];
}

+ (instancetype)scaleDownEffect
{
    return [[self alloc] initRevenantWithWholeSymbol:NO direction:RevenantSymbolEffectDirectionDown];
}

- (instancetype)effectWithByLayer
{
    return [[[self class] alloc] initRevenantWithWholeSymbol:NO direction:self.revenant_direction];
}

- (instancetype)effectWithWholeSymbol
{
    return [[[self class] alloc] initRevenantWithWholeSymbol:YES direction:self.revenant_direction];
}

- (CAAnimation *)revenant_animationForView:(UIView *)view options:(NSSymbolEffectOptions *)options
{
    NSNumber *peak = self.revenant_direction == RevenantSymbolEffectDirectionDown ? @0.9 : @1.1;
    return revenant_keyframes(@"transform.scale", @[@1, peak, @1], options);
}

@end

@interface NSSymbolVariableColorEffect (RevenantFlags)
- (instancetype)revenant_effectWithFlags:(NSUInteger)flags;
@end

@implementation NSSymbolVariableColorEffect {
    NSUInteger _flags;
}

- (instancetype)revenant_effectWithFlags:(NSUInteger)flags
{
    NSSymbolVariableColorEffect *effect = [[[self class] alloc] initRevenantWithWholeSymbol:NO direction:RevenantSymbolEffectDirectionDefault];
    effect->_flags = flags;
    return effect;
}

+ (instancetype)effect
{
    return [[self alloc] initRevenantWithWholeSymbol:NO direction:RevenantSymbolEffectDirectionDefault];
}

- (instancetype)effectWithIterative
{
    return [self revenant_effectWithFlags:_flags | 1];
}

- (instancetype)effectWithCumulative
{
    return [self revenant_effectWithFlags:_flags | 2];
}

- (instancetype)effectWithReversing
{
    return [self revenant_effectWithFlags:_flags | 4];
}

- (instancetype)effectWithNonReversing
{
    return [self revenant_effectWithFlags:_flags | 8];
}

- (instancetype)effectWithHideInactiveLayers
{
    return [self revenant_effectWithFlags:_flags | 16];
}

- (instancetype)effectWithDimInactiveLayers
{
    return [self revenant_effectWithFlags:_flags | 32];
}

- (CAAnimation *)revenant_animationForView:(UIView *)view options:(NSSymbolEffectOptions *)options
{
    return nil;
}

@end
