#import <CoreSpotlight/CoreSpotlight.h>

static BOOL RevenantSpotlightValuesEqual(id a, id b)
{
    return a == b || [a isEqual:b];
}

@implementation CSPerson

@synthesize displayName = _displayName;
@synthesize handles = _handles;
@synthesize handleIdentifier = _handleIdentifier;
@synthesize contactIdentifier = _contactIdentifier;

- (instancetype)initWithDisplayName:(NSString *)displayName
                            handles:(NSArray<NSString *> *)handles
                   handleIdentifier:(NSString *)handleIdentifier
{
    if ((self = [super init])) {
        _displayName = displayName;
        _handles = handles;
        _handleIdentifier = handleIdentifier;
    }
    return self;
}

- (NSString *)contactIdentifier
{
    @synchronized (self) {
        return _contactIdentifier;
    }
}

- (void)setContactIdentifier:(NSString *)contactIdentifier
{
    @synchronized (self) {
        _contactIdentifier = [contactIdentifier copy];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    CSPerson *copy = [[CSPerson allocWithZone:zone] initWithDisplayName:self.displayName
                                                                handles:self.handles
                                                       handleIdentifier:self.handleIdentifier];
    copy.contactIdentifier = self.contactIdentifier;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[CSPerson class]])
        return NO;
    CSPerson *person = other;
    return RevenantSpotlightValuesEqual(self.displayName, person.displayName)
        && RevenantSpotlightValuesEqual(self.handles, person.handles)
        && RevenantSpotlightValuesEqual(self.handleIdentifier, person.handleIdentifier)
        && RevenantSpotlightValuesEqual(self.contactIdentifier, person.contactIdentifier);
}

- (NSUInteger)hash
{
    return self.displayName.hash ^ self.handles.hash ^ self.handleIdentifier.hash ^ self.contactIdentifier.hash;
}

- (NSString *)description
{
    NSString *handles = [self.handles componentsJoinedByString:@", "];
    return [NSString stringWithFormat:@"<%@:%p %@ <%@>", NSStringFromClass([self class]), self, self.displayName, handles];
}

- (NSString *)debugDescription
{
    return [self description];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _displayName = [coder decodeObjectForKey:@"displayName"];
        _handles = [coder decodeObjectForKey:@"handles"];
        _handleIdentifier = [coder decodeObjectForKey:@"handleIdentifier"];
        _contactIdentifier = [coder decodeObjectForKey:@"contactIdentifier"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeObject:self.handles forKey:@"handles"];
    [coder encodeObject:self.handleIdentifier forKey:@"handleIdentifier"];
    [coder encodeObject:self.contactIdentifier forKey:@"contactIdentifier"];
}

@end
