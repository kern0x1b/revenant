#import "RevenantSymbolEffects.h"

#import <objc/message.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wprotocol"

@implementation NSSymbolEffectOptions {
    BOOL _repeating;
    NSInteger _repeatCount;
    double _speed;
}

- (BOOL)revenant_repeating
{
    return _repeating;
}

- (NSInteger)revenant_repeatCount
{
    return _repeatCount;
}

- (double)revenant_speed
{
    return _speed;
}

- (instancetype)initRevenantWithRepeating:(BOOL)repeating repeatCount:(NSInteger)repeatCount speed:(double)speed
{
    if ((self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init")))) {
        _repeating = repeating;
        _repeatCount = repeatCount;
        _speed = speed;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

+ (instancetype)options
{
    return [[self alloc] initRevenantWithRepeating:NO repeatCount:0 speed:1];
}

- (instancetype)revenant_optionsWithRepeating:(BOOL)repeating repeatCount:(NSInteger)repeatCount speed:(double)speed
{
    return [[[self class] alloc] initRevenantWithRepeating:repeating repeatCount:repeatCount speed:speed];
}

+ (instancetype)optionsWithRepeating
{
    return [[self options] optionsWithRepeating];
}

- (instancetype)optionsWithRepeating
{
    return [self revenant_optionsWithRepeating:YES repeatCount:0 speed:_speed];
}

+ (instancetype)optionsWithNonRepeating
{
    return [[self options] optionsWithNonRepeating];
}

- (instancetype)optionsWithNonRepeating
{
    return [self revenant_optionsWithRepeating:NO repeatCount:0 speed:_speed];
}

+ (instancetype)optionsWithRepeatCount:(NSInteger)count
{
    return [[self options] optionsWithRepeatCount:count];
}

- (instancetype)optionsWithRepeatCount:(NSInteger)count
{
    return [self revenant_optionsWithRepeating:YES repeatCount:count speed:_speed];
}

+ (instancetype)optionsWithSpeed:(double)speed
{
    return [[self options] optionsWithSpeed:speed];
}

- (instancetype)optionsWithSpeed:(double)speed
{
    return [self revenant_optionsWithRepeating:_repeating repeatCount:_repeatCount speed:speed];
}

@end
