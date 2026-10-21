#import "RevenantAccessibility.h"

#import "RevenantCoding.h"

#pragma mark - AXRequest

@implementation AXRequest {
    NSString *_servingTechnology;
}

- (instancetype)revenant_withTechnology:(AXTechnology)technology
{
    AXRequest *request = [[AXRequest alloc] init];
    [request revenant_setTechnology:technology];
    return request;
}

- (void)revenant_setTechnology:(AXTechnology)technology
{
    _servingTechnology = [technology copy];
}

- (AXTechnology)technology
{
    return _servingTechnology;
}

+ (AXRequest *)currentRequest
{
    return nil;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    AXRequest *copy = [[AXRequest allocWithZone:zone] revenant_withTechnology:_servingTechnology];
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AXRequest technology %@>", _servingTechnology ?: @"(none)"];
}

@end
