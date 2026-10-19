#import <CoreLocation/CoreLocation.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CLFloor {
    NSInteger _level;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithRevenantLevel:(NSInteger)level
{
    if ((self = [super init]))
        _level = level;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithRevenantLevel:[coder decodeIntegerForKey:@"level"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_level forKey:@"level"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithRevenantLevel:_level];
}

- (NSInteger)level
{
    return _level;
}

@end
