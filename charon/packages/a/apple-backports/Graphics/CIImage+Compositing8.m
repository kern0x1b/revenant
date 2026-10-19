#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// Made of what iOS 6's CoreImage already has: the source-over composite filter of iOS 5, and a
// filter given its inputs by key. Held to the host by tests/backports/host/ciimage.

@implementation CIImage (CharonCompositing)

- (CIImage *)imageByCompositingOverImage:(CIImage *)dest
{
    // Over nothing the image is itself, the same object on the host; the filter would give nil.
    if (!dest)
        return self;
    CIFilter *filter = [CIFilter filterWithName:@"CISourceOverCompositing"];
    [filter setValue:self forKey:kCIInputImageKey];
    [filter setValue:dest forKey:kCIInputBackgroundImageKey];
    return filter.outputImage;
}

@end

@implementation CIFilter (CharonInputParameters)

// filterWithName: of iOS already gives the filter its default values; a key the filter does not
// have raises NSUnknownKeyException, as the host's does.
+ (CIFilter *)filterWithName:(NSString *)name withInputParameters:(NSDictionary<NSString *, id> *)params
{
    CIFilter *filter = [CIFilter filterWithName:name];
    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        [filter setValue:value forKey:key];
    }];
    return filter;
}

@end
