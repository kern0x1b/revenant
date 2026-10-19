#import <Foundation/Foundation.h>

@implementation NSUnit

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    [NSException raise:NSGenericException format:@"-init should never be called on NSUnit!"];
    return nil;
}

- (instancetype)initWithSymbol:(NSString *)symbol
{
    if ((self = [super init]))
        _symbol = [symbol copy];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSUnit cannot be decoded by non-keyed archivers"];
        return nil;
    }
    NSString *symbol = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.symbol"];
    if (!symbol) {
        [coder failWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderValueNotFoundError userInfo:nil]];
        return nil;
    }
    return [self initWithSymbol:symbol];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSUnit encoder does not allow non-keyed coding!"];
        return;
    }
    [coder encodeObject:_symbol forKey:@"NS.symbol"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)symbol
{
    return _symbol;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]] || [object class] != [self class])
        return NO;
    return [_symbol isEqual:[object symbol]];
}

- (NSString *)description
{
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" %@", _symbol]];
}

@end
