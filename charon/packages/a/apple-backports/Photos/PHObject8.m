#import "CharonPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation PHObject {
    NSString *_localIdentifier;
}

- (instancetype)initWithCharonLocalIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self)
        _localIdentifier = [identifier copy];
    return self;
}

- (NSString *)localIdentifier
{
    return _localIdentifier;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

// An object read again after a change of the library; the subclasses that ALAssetsLibrary can read again
// answer with a fresh object, or nil once it is gone.
- (PHObject *)charon_refetched
{
    return self;
}

- (BOOL)charon_sameStateAs:(PHObject *)other
{
    return [self isEqual:other];
}

- (BOOL)isEqual:(id)object
{
    return self == object || ([object isMemberOfClass:[self class]] && [[object localIdentifier] isEqualToString:self.localIdentifier]);
}

- (NSUInteger)hash
{
    return self.localIdentifier.hash;
}

@end

@implementation PHObjectPlaceholder

- (NSString *)localIdentifier
{
    return [CharonPhotosStore resolvedIdentifier:[super localIdentifier]];
}

@end
