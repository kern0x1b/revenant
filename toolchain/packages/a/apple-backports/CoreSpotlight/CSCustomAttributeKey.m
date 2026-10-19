#import <CoreSpotlight/CoreSpotlight.h>

static NSCharacterSet *RevenantCustomKeyRefused(void)
{
    static NSCharacterSet *refused;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        refused = [NSCharacterSet characterSetWithCharactersInString:@"!\"#%&'()*,-./:;?@[\\]{}"];
    });
    return refused;
}

static BOOL RevenantCustomKeyNameIsValid(NSString *keyName)
{
    if (!keyName)
        return NO;
    NSCharacterSet *refused = RevenantCustomKeyRefused();
    for (NSUInteger i = 0; i < keyName.length; i++) {
        unichar c = [keyName characterAtIndex:i];
        if (c > 127 || [refused characterIsMember:c])
            return NO;
    }
    return YES;
}

@implementation CSCustomAttributeKey

@synthesize keyName = _keyName;
@synthesize searchable = _searchable;
@synthesize searchableByDefault = _searchableByDefault;
@synthesize unique = _unique;
@synthesize multiValued = _multiValued;

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"You must call -[CSCustomAttributeKey initWithKeyName...]"];
    return nil;
}

- (instancetype)initWithKeyName:(NSString *)keyName
{
    return [self initWithKeyName:keyName searchable:YES searchableByDefault:NO unique:NO multiValued:NO];
}

- (instancetype)initWithKeyName:(NSString *)keyName
                     searchable:(BOOL)searchable
            searchableByDefault:(BOOL)searchableByDefault
                         unique:(BOOL)unique
                    multiValued:(BOOL)multiValued
{
    if (!RevenantCustomKeyNameIsValid(keyName))
        return nil;
    if ((self = [super init])) {
        _keyName = keyName;
        _searchable = searchable;
        _searchableByDefault = searchableByDefault;
        _unique = unique;
        _multiValued = multiValued;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[CSCustomAttributeKey allocWithZone:zone] initWithKeyName:self.keyName searchable:self.searchable
                                                  searchableByDefault:self.searchableByDefault unique:self.unique
                                                          multiValued:self.multiValued];
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if ([other isKindOfClass:[CSCustomAttributeKey class]])
        return [self.keyName isEqualToString:((CSCustomAttributeKey *)other).keyName];
    return [self.keyName isEqual:other];
}

- (NSUInteger)hash
{
    return self.keyName.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p %@", NSStringFromClass([self class]), self, self.keyName];
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
    return [self initWithKeyName:[coder decodeObjectForKey:@"keyName"] searchable:[coder decodeBoolForKey:@"searchable"]
             searchableByDefault:[coder decodeBoolForKey:@"searchableByDefault"] unique:[coder decodeBoolForKey:@"unique"]
                     multiValued:[coder decodeBoolForKey:@"multiValued"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.keyName forKey:@"keyName"];
    [coder encodeBool:self.searchable forKey:@"searchable"];
    [coder encodeBool:self.searchableByDefault forKey:@"searchableByDefault"];
    [coder encodeBool:self.unique forKey:@"unique"];
    [coder encodeBool:self.multiValued forKey:@"multiValued"];
}

@end
