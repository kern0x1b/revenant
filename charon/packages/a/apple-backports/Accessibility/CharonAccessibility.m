#import "CharonAccessibility.h"

#import "../../../c/charon-coding/files/CharonCoding.h"

#pragma mark - AXRequest

@implementation AXRequest {
    NSString *_servingTechnology;
}

- (instancetype)charon_withTechnology:(AXTechnology)technology
{
    AXRequest *request = [[AXRequest alloc] init];
    [request charon_setTechnology:technology];
    return request;
}

- (void)charon_setTechnology:(AXTechnology)technology
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
        charon_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    AXRequest *copy = [[AXRequest allocWithZone:zone] charon_withTechnology:_servingTechnology];
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AXRequest technology %@>", _servingTechnology ?: @"(none)"];
}

@end
