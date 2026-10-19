#import <CoreSpotlight/CoreSpotlight.h>

// The ASCII punctuation a key name may not hold, as the host refuses it. Every character outside ASCII is refused too. The host
// takes the other ASCII punctuation ($ + < = > ^ _ ` | ~), the controls, the space and the delete character, and it sets no length
// limit (measured up to 10010 characters). A name with a NUL or a tab is accepted (measured).
static NSCharacterSet *CharonCustomKeyRefused(void)
{
    static NSCharacterSet *refused;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        refused = [NSCharacterSet characterSetWithCharactersInString:@"!\"#%&'()*,-./:;?@[\\]{}"];
    });
    return refused;
}

static BOOL CharonCustomKeyNameIsValid(NSString *keyName)
{
    if (!keyName)
        return NO;
    NSCharacterSet *refused = CharonCustomKeyRefused();
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

// The release does not allow a key without a name: it raises NSInvalidArgumentException with this reason (measured).
- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"You must call -[CSCustomAttributeKey initWithKeyName...]"];
    return nil;
}

- (instancetype)initWithKeyName:(NSString *)keyName
{
    return [self initWithKeyName:keyName searchable:YES searchableByDefault:NO unique:NO multiValued:NO];
}

// A name the release refuses gives no key at all: the answer is nil, not an exception (measured). The name is kept as it was
// given, not copied: a mutable name changed after the key is made is seen through it (measured).
- (instancetype)initWithKeyName:(NSString *)keyName
                     searchable:(BOOL)searchable
            searchableByDefault:(BOOL)searchableByDefault
                         unique:(BOOL)unique
                    multiValued:(BOOL)multiValued
{
    if (!CharonCustomKeyNameIsValid(keyName))
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

// A key is equal to another key of the same name, and to a string of that name (measured: the host compares the string with the
// name). Nothing else is equal to it. Its hash is the hash of the name, so the two agree.
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

// The host's text is "<CSCustomAttributeKey:ADDRESS NAME", with no closing angle bracket, like CSPerson's.
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

// An archive holding a name the release would refuse decodes to nil here: the host's answer for that is not measured.
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
