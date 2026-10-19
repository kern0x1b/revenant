#import <Foundation/Foundation.h>

/* The name of the exception Apple's own NSPersonNameComponents raises for a read it will not answer.
   Spelled as the string it is, because an exception's name *is* a string and 6.1.3 does not export the
   symbol (measured with tools/corpus/cache-value.lua over the 6.1.3 armv7 cache: absent), so a
   reference to it would not link. Raising with this string gives an exception that compares equal to
   the release's own. */

@implementation NSPersonNameComponents {
@private
    NSString *_namePrefix;
    NSString *_givenName;
    NSString *_middleName;
    NSString *_familyName;
    NSString *_nameSuffix;
    NSString *_nickname;
    NSPersonNameComponents *_phoneticRepresentation;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (NSString *)namePrefix { return _namePrefix; }
- (void)setNamePrefix:(NSString *)value { _namePrefix = [value copy]; }
- (NSString *)givenName { return _givenName; }
- (void)setGivenName:(NSString *)value { _givenName = [value copy]; }
- (NSString *)middleName { return _middleName; }
- (void)setMiddleName:(NSString *)value { _middleName = [value copy]; }
- (NSString *)familyName { return _familyName; }
- (void)setFamilyName:(NSString *)value { _familyName = [value copy]; }
- (NSString *)nameSuffix { return _nameSuffix; }
- (void)setNameSuffix:(NSString *)value { _nameSuffix = [value copy]; }
- (NSString *)nickname { return _nickname; }
- (void)setNickname:(NSString *)value { _nickname = [value copy]; }
- (NSPersonNameComponents *)phoneticRepresentation { return _phoneticRepresentation; }

/* The release refuses to read a component *through* the phonetic representation when the spelling has
   not got it, and the abbreviated template reads exactly that way, so an abbreviated style over a
   phonetic representation raises on every current system (measured on the host, ten locales, and
   reproducible from any caller with one public call:
   [components valueForKey:@"phoneticRepresentation.givenName"]). The same read is refused here, in
   the release's own words, so the port's answer is the release's answer rather than a quiet two
   initials where every current system throws. */
- (id)valueForUndefinedKey:(NSString *)key
{
    if ([key hasPrefix:@"phoneticRepresentation."]) {
        NSString *component = [key substringFromIndex:@"phoneticRepresentation.".length];
        if (component.length) {
            [NSException raise:@"NSUnknownKeyException"
                        format:@"[<%@ valueForUndefinedKey:>]: this class is not key value coding-compliant for the key %@",
                               NSStringFromClass([self class]), key];
            return nil;
        }
    }
    [NSException raise:@"NSUnknownKeyException"
                format:@"[<%@ valueForUndefinedKey:>]: this class is not key value coding-compliant for the key %@",
                       NSStringFromClass([self class]), key];
    return nil;
}
- (void)setPhoneticRepresentation:(NSPersonNameComponents *)value { _phoneticRepresentation = [value copy]; }

- (id)copyWithZone:(NSZone *)zone
{
    NSPersonNameComponents *copy = [[[self class] allocWithZone:zone] init];
    copy->_namePrefix = [_namePrefix copy];
    copy->_givenName = [_givenName copy];
    copy->_middleName = [_middleName copy];
    copy->_familyName = [_familyName copy];
    copy->_nameSuffix = [_nameSuffix copy];
    copy->_nickname = [_nickname copy];
    copy->_phoneticRepresentation = [_phoneticRepresentation copy];
    return copy;
}

static BOOL charon_same(id left, id right)
{
    return left == right || [left isEqual:right];
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[NSPersonNameComponents class]])
        return NO;
    NSPersonNameComponents *components = other;
    return charon_same(_namePrefix, components->_namePrefix) && charon_same(_givenName, components->_givenName) && charon_same(_middleName, components->_middleName) &&
        charon_same(_familyName, components->_familyName) && charon_same(_nameSuffix, components->_nameSuffix) && charon_same(_nickname, components->_nickname) &&
        charon_same(_phoneticRepresentation, components->_phoneticRepresentation);
}

- (NSUInteger)hash
{
    return _namePrefix.hash ^ _givenName.hash ^ (_middleName.hash << 1) ^ (_familyName.hash << 2) ^ (_nameSuffix.hash << 3) ^ (_nickname.hash << 4) ^ (_phoneticRepresentation.hash << 5);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> {givenName = %@, familyName = %@, middleName = %@, namePrefix = %@, nameSuffix = %@, nickname = %@ phoneticRepresentation = %@ }", [self class], self, _givenName, _familyName, _middleName, _namePrefix, _nameSuffix, _nickname, _phoneticRepresentation];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSString *keys[] = {@"NS.namePrefix", @"NS.givenName", @"NS.middleName", @"NS.familyName", @"NS.nameSuffix", @"NS.nickname"};
    NSString *values[] = {_namePrefix, _givenName, _middleName, _familyName, _nameSuffix, _nickname};
    for (size_t index = 0; index < 6; index++)
        if (values[index])
            [coder encodeObject:values[index] forKey:keys[index]];
    if (_phoneticRepresentation)
        [coder encodeObject:_phoneticRepresentation forKey:@"NS.phoneticRepresentation"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _namePrefix = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.namePrefix"] copy];
        _givenName = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.givenName"] copy];
        _middleName = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.middleName"] copy];
        _familyName = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.familyName"] copy];
        _nameSuffix = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.nameSuffix"] copy];
        _nickname = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.nickname"] copy];
        _phoneticRepresentation = [coder decodeObjectOfClass:[NSPersonNameComponents class] forKey:@"NS.phoneticRepresentation"];
    }
    return self;
}

@end
