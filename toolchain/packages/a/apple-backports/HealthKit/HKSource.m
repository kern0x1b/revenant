#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKSource {
    NSString *_name;
    NSString *_bundleIdentifier;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_sourceWithName:(NSString *)name bundleIdentifier:(NSString *)bundleIdentifier
{
    return [[self alloc] charon_initWithName:name bundleIdentifier:bundleIdentifier];
}

+ (instancetype)defaultSource
{
    static HKSource *source;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSDictionary *info = [bundle localizedInfoDictionary] ?: [bundle infoDictionary];
        NSString *name = [info objectForKey:@"CFBundleDisplayName"] ?: [info objectForKey:@"CFBundleName"];
        if (![name isKindOfClass:[NSString class]])
            name = [info objectForKey:@"CFBundleExecutable"];
        if (![name isKindOfClass:[NSString class]])
            name = @"";
        NSString *identifier = [bundle bundleIdentifier] ?: @"";
        source = [HKSource charon_sourceWithName:name bundleIdentifier:identifier];
    });
    return source;
}

- (instancetype)charon_initWithName:(NSString *)name bundleIdentifier:(NSString *)bundleIdentifier
{
    HKSource *fresh = [super init];
    if (fresh) {
        fresh->_name = [name copy] ?: @"";
        fresh->_bundleIdentifier = [bundleIdentifier copy] ?: @"";
    }
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
    NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"bundleIdentifier"];
    return [self charon_initWithName:name ?: @"" bundleIdentifier:identifier ?: @""];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_bundleIdentifier forKey:@"bundleIdentifier"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKSource charon_sourceWithName:_name bundleIdentifier:_bundleIdentifier];
}

- (instancetype)charon_copyForStore
{
    return [HKSource charon_sourceWithName:_name bundleIdentifier:_bundleIdentifier];
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[HKSource class]])
        return NO;
    HKSource *that = other;
    return [_name isEqualToString:that.name] && [_bundleIdentifier isEqualToString:that.bundleIdentifier];
}

- (NSUInteger)hash
{
    return _name.hash ^ _bundleIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKSource[%@ %@]", _name, _bundleIdentifier];
}

- (NSString *)name
{
    return _name;
}

- (NSString *)bundleIdentifier
{
    return _bundleIdentifier;
}

- (NSComparisonResult)charon_compare:(HKSource *)other
{
    NSComparisonResult result = [_name compare:other.name];
    if (result != NSOrderedSame)
        return result;
    return [_bundleIdentifier compare:other.bundleIdentifier];
}

@end
