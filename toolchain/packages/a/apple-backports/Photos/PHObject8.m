#import "RevenantPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation PHObject {
    NSString *_localIdentifier;
}

- (instancetype)initWithRevenantLocalIdentifier:(NSString *)identifier
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

- (PHObject *)revenant_refetched
{
    return self;
}

- (BOOL)revenant_sameStateAs:(PHObject *)other
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
    return [RevenantPhotosStore resolvedIdentifier:[super localIdentifier]];
}

@end
