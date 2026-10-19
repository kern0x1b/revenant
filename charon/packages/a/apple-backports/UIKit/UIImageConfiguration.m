#import "CharonSymbols.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *const CharonTraitsKey = @"UITraitCollection";

NSString *charon_trait_summary(UITraitCollection *traits)
{
    NSString *text = [traits description];
    NSRange start = [text rangeOfString:@"; "];
    if (start.location == NSNotFound || ![text hasSuffix:@">"])
        return @"";
    return [text substringWithRange:NSMakeRange(NSMaxRange(start), text.length - 1 - NSMaxRange(start))];
}

@implementation UIImageConfiguration {
@protected
    UITraitCollection *_traits;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// The header redeclares -init NS_UNAVAILABLE. A configuration made by -init specifies nothing, which is the
// configuration with no trait collection that the designated initialiser gives.
- (instancetype)init
{
    return [self initCharonWithTraitCollection:nil];
}

- (instancetype)initCharonWithTraitCollection:(UITraitCollection *)traits
{
    if ((self = [super init]))
        _traits = traits;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        _traits = [coder decodeObjectOfClass:[UITraitCollection class] forKey:CharonTraitsKey];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_traits)
        [coder encodeObject:_traits forKey:CharonTraitsKey];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initCharonWithTraitCollection:_traits];
}

- (UITraitCollection *)traitCollection
{
    return _traits;
}

- (instancetype)configurationWithTraitCollection:(UITraitCollection *)traitCollection
{
    if (traitCollection && ![traitCollection isKindOfClass:[UITraitCollection class]])
        [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: unrecognized selector sent to instance %p", [traitCollection class], @"_traitCollectionRelevantForImageConfiguration", traitCollection];
    if (traitCollection == _traits || [traitCollection isEqual:_traits])
        return self;
    UIImageConfiguration *copy = [self copy];
    copy->_traits = traitCollection;
    return copy;
}

- (instancetype)configurationByApplyingConfiguration:(UIImageConfiguration *)otherConfiguration
{
    if (!otherConfiguration)
        return self;
    if (![otherConfiguration isKindOfClass:[UIImageConfiguration class]])
        [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: unrecognized selector sent to instance %p", [otherConfiguration class], @"_isUnspecified", otherConfiguration];
    if ([otherConfiguration charon_isUnspecified])
        return self;
    UIImageConfiguration *result = [self copy];
    if (![self isKindOfClass:[otherConfiguration class]])
        return result;
    UITraitCollection *other = otherConfiguration->_traits;
    if (other)
        result->_traits = _traits ? [UITraitCollection traitCollectionWithTraitsFromCollections:@[_traits, other]] : other;
    [result charon_applyFieldsOfConfiguration:otherConfiguration];
    return result;
}

- (BOOL)charon_isUnspecified
{
    return !_traits;
}

- (void)charon_applyFieldsOfConfiguration:(UIImageConfiguration *)other
{
}

- (NSMutableArray<NSString *> *)charon_fieldDescriptions
{
    return [NSMutableArray array];
}

- (BOOL)charon_hasTraitsOfConfiguration:(UIImageConfiguration *)otherConfiguration
{
    UITraitCollection *other = otherConfiguration->_traits;
    return other == _traits || [other isEqual:_traits];
}

- (BOOL)isEqualToConfiguration:(UIImageConfiguration *)otherConfiguration
{
    if (otherConfiguration == self)
        return YES;
    return otherConfiguration && [otherConfiguration class] == [self class] && [self charon_hasTraitsOfConfiguration:otherConfiguration];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[UIImageConfiguration class]] || !object ? [self isEqualToConfiguration:object] : NO;
}

- (NSUInteger)hash
{
    return _traits.hash;
}

- (NSString *)description
{
    NSMutableArray *fields = [self charon_fieldDescriptions];
    if (_traits)
        [fields addObject:[NSString stringWithFormat:@"traits=(%@)", charon_trait_summary(_traits)]];
    return fields.count ? [fields componentsJoinedByString:@", "] : @"unspecified";
}

@end
