#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@implementation ASCredentialServiceIdentifier

@synthesize identifier = _identifier;
@synthesize type = _type;

- (instancetype)initWithIdentifier:(NSString *)identifier type:(ASCredentialServiceIdentifierType)type
{
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _type = type;
    }
    return self;
}

- (NSString *)identifier
{
    return [_identifier copy];
}

- (ASCredentialServiceIdentifierType)type
{
    return _type;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithIdentifier:_identifier type:_type];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"]
                               type:(ASCredentialServiceIdentifierType)[coder decodeIntegerForKey:@"type"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeInteger:(NSInteger)_type forKey:@"type"];
}

@end
