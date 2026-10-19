#import "CharonNEHotspot.h"

/* The Hotspot 2.0 settings object: property storage, `copy` and the keyed archive, as the host answers them
   (tests/backports/host/netext-hotspot/probe.m, ops hs20 and wiring). The domain name is set by the initializer
   and read only; the Boolean is a value; the three lists are copied on set and by -copy. */
@implementation NEHotspotHS20Settings {
    NSString *_domainName;
    BOOL _roamingEnabled;
    NSArray<NSString *> *_roamingConsortiumOIs;
    NSArray<NSString *> *_naiRealmNames;
    NSArray<NSString *> *_MCCAndMNCs;
}

@synthesize domainName = _domainName;
@synthesize roamingEnabled = _roamingEnabled;
@synthesize roamingConsortiumOIs = _roamingConsortiumOIs;
@synthesize naiRealmNames = _naiRealmNames;
@synthesize MCCAndMNCs = _MCCAndMNCs;

- (instancetype)initWithDomainName:(NSString *)domainName roamingEnabled:(BOOL)roamingEnabled
{
    self = [super init];
    if (self) {
        _domainName = [domainName copy];
        _roamingEnabled = roamingEnabled;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NEHotspotHS20Settings *copy = [[NEHotspotHS20Settings allocWithZone:zone] initWithDomainName:_domainName
                                                                                 roamingEnabled:_roamingEnabled];
    copy.roamingConsortiumOIs = _roamingConsortiumOIs;
    copy.naiRealmNames = _naiRealmNames;
    copy.MCCAndMNCs = _MCCAndMNCs;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        NSSet *lists = [NSSet setWithObjects:[NSArray class], [NSString class], nil];
        _domainName = [[coder decodeObjectOfClass:[NSString class] forKey:@"domainName"] copy];
        _roamingEnabled = [coder decodeBoolForKey:@"roamingEnabled"];
        _roamingConsortiumOIs = [[coder decodeObjectOfClasses:lists forKey:@"roamingConsortiumOIs"] copy];
        _naiRealmNames = [[coder decodeObjectOfClasses:lists forKey:@"naiRealmNames"] copy];
        _MCCAndMNCs = [[coder decodeObjectOfClasses:lists forKey:@"MCCAndMNCs"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_domainName forKey:@"domainName"];
    [coder encodeBool:_roamingEnabled forKey:@"roamingEnabled"];
    [coder encodeObject:_roamingConsortiumOIs forKey:@"roamingConsortiumOIs"];
    [coder encodeObject:_naiRealmNames forKey:@"naiRealmNames"];
    [coder encodeObject:_MCCAndMNCs forKey:@"MCCAndMNCs"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
