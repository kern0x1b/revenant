#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CIImage (CharonFilterParameters)

- (CIImage *)imageByApplyingFilter:(NSString *)filterName withInputParameters:(NSDictionary<NSString *, id> *)params
{
    CIFilter *filter = [CIFilter filterWithName:filterName];
    if (!filter)
        return nil;
    [filter setDefaults];
    [filter setValue:self forKey:kCIInputImageKey];
    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        [filter setValue:value forKey:key];
    }];
    return filter.outputImage;
}

- (CIImage *)imageByApplyingFilter:(NSString *)filterName
{
    return [self imageByApplyingFilter:filterName withInputParameters:nil];
}

@end
