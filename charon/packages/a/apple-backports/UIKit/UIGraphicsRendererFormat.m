#import "CharonGraphicsRenderer.h"

@implementation UIGraphicsRendererFormat {
@private
    CGRect _bounds;
}

+ (instancetype)defaultFormat
{
    return [[self alloc] init];
}

- (CGRect)bounds
{
    return _bounds;
}

- (void)_setBounds:(CGRect)bounds
{
    _bounds = bounds;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIGraphicsRendererFormat *copy = [[[self class] allocWithZone:zone] init];
    [copy _setBounds:self.bounds];
    return copy;
}

@end
