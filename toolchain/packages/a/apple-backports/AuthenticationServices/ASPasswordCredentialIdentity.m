#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@implementation ASPasswordCredentialIdentity

@synthesize serviceIdentifier = _serviceIdentifier;
@synthesize user = _user;
@synthesize recordIdentifier = _recordIdentifier;
@synthesize rank = _rank;

- (instancetype)initWithServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier
                                    user:(NSString *)user
                        recordIdentifier:(NSString *)recordIdentifier
{
    self = [super init];
    if (self) {
        _serviceIdentifier = serviceIdentifier;
        _user = [user copy];
        _recordIdentifier = [recordIdentifier copy];
        _rank = 0;
    }
    return self;
}

+ (instancetype)identityWithServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier
                                        user:(NSString *)user
                            recordIdentifier:(NSString *)recordIdentifier
{
    return [[self alloc] initWithServiceIdentifier:serviceIdentifier user:user recordIdentifier:recordIdentifier];
}

- (ASCredentialServiceIdentifier *)serviceIdentifier
{
    return _serviceIdentifier;
}

- (NSString *)user
{
    return [_user copy];
}

- (NSString *)recordIdentifier
{
    return [_recordIdentifier copy];
}

- (NSInteger)rank
{
    return _rank;
}

- (void)setRank:(NSInteger)rank
{
    _rank = rank;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    ASPasswordCredentialIdentity *copy = [[[self class] allocWithZone:zone] initWithServiceIdentifier:_serviceIdentifier
                                                                                    user:_user
                                                                        recordIdentifier:_recordIdentifier];
    copy.rank = _rank;
    return copy;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self initWithServiceIdentifier:[coder decodeObjectOfClass:[ASCredentialServiceIdentifier class]
                                                              forKey:@"serviceIdentifier"]
                                      user:[coder decodeObjectOfClass:[NSString class] forKey:@"user"]
                          recordIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"recordIdentifier"]];
    if (self)
        _rank = [coder decodeIntegerForKey:@"rank"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_serviceIdentifier forKey:@"serviceIdentifier"];
    [coder encodeObject:_user forKey:@"user"];
    [coder encodeObject:_recordIdentifier forKey:@"recordIdentifier"];
    [coder encodeInteger:(NSInteger)_rank forKey:@"rank"];
}

@end
