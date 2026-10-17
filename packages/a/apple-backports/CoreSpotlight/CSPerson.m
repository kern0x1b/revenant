#import <CoreSpotlight/CoreSpotlight.h>

// Equal when both are nil, or when isEqual: says so. The host compares nil and @"" as different values.
static BOOL CharonSpotlightValuesEqual(id a, id b)
{
    return a == b || [a isEqual:b];
}

@implementation CSPerson

@synthesize displayName = _displayName;
@synthesize handles = _handles;
@synthesize handleIdentifier = _handleIdentifier;
@synthesize contactIdentifier = _contactIdentifier;

// The host keeps the three values it is given as they are: a mutable string or array passed in is seen through the
// person afterwards. contactIdentifier is the one copied, as its declaration says.
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

// The property is atomic, as the header declares it, so its accessors are both written here and both take the lock.
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

// Value equality over the four properties, in the order the handles are kept: a different order is a different person.
- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[CSPerson class]])
        return NO;
    CSPerson *person = other;
    return CharonSpotlightValuesEqual(self.displayName, person.displayName)
        && CharonSpotlightValuesEqual(self.handles, person.handles)
        && CharonSpotlightValuesEqual(self.handleIdentifier, person.handleIdentifier)
        && CharonSpotlightValuesEqual(self.contactIdentifier, person.contactIdentifier);
}

- (NSUInteger)hash
{
    return self.displayName.hash ^ self.handles.hash ^ self.handleIdentifier.hash ^ self.contactIdentifier.hash;
}

// The host's text is "<CSPerson:ADDRESS NAME <HANDLE, HANDLE>" - a nil name or a nil handle list prints as "(null)", and the closing
// angle bracket is not there. The debug text is the same text.
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
        _displayName = [coder decodeObjectOfClass:[NSString class] forKey:@"displayName"];
        _handles = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil] forKey:@"handles"];
        _handleIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"handleIdentifier"];
        _contactIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"contactIdentifier"];
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
