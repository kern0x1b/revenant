#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CIImage (RevenantCompositing)

- (CIImage *)imageByCompositingOverImage:(CIImage *)dest
{
    if (!dest)
        return self;
    CIFilter *filter = [CIFilter filterWithName:@"CISourceOverCompositing"];
    [filter setValue:self forKey:kCIInputImageKey];
    [filter setValue:dest forKey:kCIInputBackgroundImageKey];
    return filter.outputImage;
}

@end

@implementation CIFilter (RevenantInputParameters)

+ (CIFilter *)filterWithName:(NSString *)name withInputParameters:(NSDictionary<NSString *, id> *)params
{
    CIFilter *filter = [CIFilter filterWithName:name];
    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        [filter setValue:value forKey:key];
    }];
    return filter;
}

@end
