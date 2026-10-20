#import <Foundation/Foundation.h>
#import <Messages/MSSession.h>

@implementation MSSession

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)other
{
    return other == self;
}

- (NSUInteger)hash
{
    return (NSUInteger)self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> session", NSStringFromClass([self class]), self];
}

@end
