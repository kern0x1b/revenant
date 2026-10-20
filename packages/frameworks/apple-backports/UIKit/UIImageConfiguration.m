#import "RevenantSymbols.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *const RevenantTraitsKey = @"UITraitCollection";

NSString *revenant_trait_summary(UITraitCollection *traits)
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

- (instancetype)init
{
    return [self initRevenantWithTraitCollection:nil];
}

- (instancetype)initRevenantWithTraitCollection:(UITraitCollection *)traits
{
    if ((self = [super init]))
        _traits = traits;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        _traits = [coder decodeObjectOfClass:[UITraitCollection class] forKey:RevenantTraitsKey];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_traits)
        [coder encodeObject:_traits forKey:RevenantTraitsKey];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initRevenantWithTraitCollection:_traits];
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
    if ([otherConfiguration revenant_isUnspecified])
        return self;
    UIImageConfiguration *result = [self copy];
    if (![self isKindOfClass:[otherConfiguration class]])
        return result;
    UITraitCollection *other = otherConfiguration->_traits;
    if (other)
        result->_traits = _traits ? [UITraitCollection traitCollectionWithTraitsFromCollections:@[_traits, other]] : other;
    [result revenant_applyFieldsOfConfiguration:otherConfiguration];
    return result;
}

- (BOOL)revenant_isUnspecified
{
    return !_traits;
}

- (void)revenant_applyFieldsOfConfiguration:(UIImageConfiguration *)other
{
}

- (NSMutableArray<NSString *> *)revenant_fieldDescriptions
{
    return [NSMutableArray array];
}

- (BOOL)revenant_hasTraitsOfConfiguration:(UIImageConfiguration *)otherConfiguration
{
    UITraitCollection *other = otherConfiguration->_traits;
    return other == _traits || [other isEqual:_traits];
}

- (BOOL)isEqualToConfiguration:(UIImageConfiguration *)otherConfiguration
{
    if (otherConfiguration == self)
        return YES;
    return otherConfiguration && [otherConfiguration class] == [self class] && [self revenant_hasTraitsOfConfiguration:otherConfiguration];
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
    NSMutableArray *fields = [self revenant_fieldDescriptions];
    if (_traits)
        [fields addObject:[NSString stringWithFormat:@"traits=(%@)", revenant_trait_summary(_traits)]];
    return fields.count ? [fields componentsJoinedByString:@", "] : @"unspecified";
}

@end
