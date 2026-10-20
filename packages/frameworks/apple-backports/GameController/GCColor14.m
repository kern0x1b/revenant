#import <GameController/GameController.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation GCColor {
    float _red;
    float _green;
    float _blue;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithRed:(float)red green:(float)green blue:(float)blue
{
    self = [super init];
    if (self) {
        _red = red;
        _green = green;
        _blue = blue;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithRed:[coder decodeFloatForKey:@"red"] green:[coder decodeFloatForKey:@"green"] blue:[coder decodeFloatForKey:@"blue"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeFloat:_red forKey:@"red"];
    [coder encodeFloat:_green forKey:@"green"];
    [coder encodeFloat:_blue forKey:@"blue"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithRed:_red green:_green blue:_blue];
}

- (float)red
{
    return _red;
}

- (float)green
{
    return _green;
}

- (float)blue
{
    return _blue;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ r=%f g=%f b=%f>", NSStringFromClass([self class]), _red, _green, _blue];
}

@end
