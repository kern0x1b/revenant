#import "RevenantPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wprotocol"

@interface PHLivePhoto ()
@property (nonatomic, readwrite) CGSize size;
@end

@implementation PHLivePhoto
@synthesize size = _size;
@end

@interface PHLivePhoto (RevenantItemProvider) <NSItemProviderReading>
@end

@implementation PHLivePhoto (RevenantItemProvider)

+ (NSArray<NSString *> *)readableTypeIdentifiersForItemProvider
{
    return @[];
}

+ (instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)typeIdentifier error:(NSError **)error
{
    if (error)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:@{NSLocalizedDescriptionKey: @"Live Photos are not available on iOS 6"}];
    return nil;
}

@end
