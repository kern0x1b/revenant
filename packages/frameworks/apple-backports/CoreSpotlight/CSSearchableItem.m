#import <CoreSpotlight/CoreSpotlight.h>

NSString * const CSSearchableItemActionType = @"com.apple.corespotlightitem";
NSString * const CSSearchableItemActivityIdentifier = @"kCSSearchableItemActivityIdentifier";

@interface CSSearchableItem ()
{
    NSDate *_expirationDate;
}
@end

@implementation CSSearchableItem

@synthesize uniqueIdentifier = _uniqueIdentifier;
@synthesize domainIdentifier = _domainIdentifier;
@synthesize attributeSet = _attributeSet;

- (instancetype)initWithUniqueIdentifier:(NSString *)uniqueIdentifier
                         domainIdentifier:(NSString *)domainIdentifier
                             attributeSet:(CSSearchableItemAttributeSet *)attributeSet
{
    if ((self = [super init])) {
        _uniqueIdentifier = uniqueIdentifier ?: [[NSUUID UUID] UUIDString];
        _domainIdentifier = domainIdentifier;
        _attributeSet = attributeSet;
    }
    return self;
}

- (NSDate *)expirationDate
{
    if (!_expirationDate)
        _expirationDate = [NSDate dateWithTimeIntervalSinceNow:30 * 24 * 60 * 60];
    return _expirationDate;
}

- (void)setExpirationDate:(NSDate *)expirationDate
{
    _expirationDate = [expirationDate copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    CSSearchableItem *copy = [[CSSearchableItem allocWithZone:zone] initWithUniqueIdentifier:self.uniqueIdentifier
                                                                              domainIdentifier:self.domainIdentifier
                                                                                  attributeSet:[self.attributeSet copy]];
    copy.expirationDate = _expirationDate;
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"uniqueIdentifier"];
    NSString *domain = [coder decodeObjectOfClass:[NSString class] forKey:@"domainIdentifier"];
    CSSearchableItemAttributeSet *attributes = [coder decodeObjectOfClass:[CSSearchableItemAttributeSet class] forKey:@"attributeSet"];
    if ((self = [self initWithUniqueIdentifier:identifier domainIdentifier:domain attributeSet:attributes]))
        _expirationDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"expirationDate"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];
    [coder encodeObject:self.domainIdentifier forKey:@"domainIdentifier"];
    [coder encodeObject:self.attributeSet forKey:@"attributeSet"];
    [coder encodeObject:_expirationDate forKey:@"expirationDate"];
}

@end
